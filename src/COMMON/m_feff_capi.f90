!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! feffjl Phase 3: the C ABI for libfeff.
!
! Phases 1 and 2 made the EXAFS chain callable, but only the way the Phase-2 gate
! fixture calls it: by the raw gfortran-mangled symbol `feff_run_exafs_`, with no
! arguments, no status, no data out, and every input taken from the process's
! current directory.  That is a linkage demonstration, not an interface.  Three
! things were missing, and this module is exactly those three things:
!
!   1. A failure has to be reportable.  Before Phase 3 a malformed feff.inp meant
!      `stop` inside rdinp -- from a Julia session, a dead REPL and a lost fit.
!   2. The caller has to be able to say WHERE to run, without the library
!      permanently moving the host's current directory to get there.
!   3. The answer has to come back as numbers, not as a file the caller must
!      re-parse.
!
! Design decisions, and why:
!
! * SINGLETON, NO HANDLE.  Earlier plan documents projected feff_init/feff_free
!   around an opaque handle.  Rejected: the chain is module-level state from end to
!   end and is not thread-safe, so there is exactly one FEFF per process no matter
!   what the signature suggests.  A handle would advertise concurrency that does
!   not exist and invite exactly the usage that breaks.  If the internals are ever
!   made reentrant, adding a handle-taking entry point alongside these is
!   source-compatible for callers.
!
! * THE LIBRARY OWNS THE WORKING DIRECTORY, briefly.  FEFF opens the hardcoded
!   name 'feff.inp' and writes ~56 files into the cwd; nothing short of rewriting
!   every open statement in the tree changes that.  So feff_exafs_run chdirs into
!   the caller's workdir and restores the previous cwd on every exit path,
!   including failures and including the case where the chdir itself failed.  The
!   alternative -- documenting "chdir before you call us" -- pushes a global side
!   effect onto the caller and makes the failure mode silent (a run that writes its
!   output into the user's home directory looks like it worked).
!
! * GETTERS COPY OUT INTO CALLER MEMORY.  No returned pointers into Fortran
!   module arrays.  Julia would have to wrap those in unsafe_wrap and would then
!   hold a pointer that the next feff_exafs_run invalidates by reallocating.  Copy
!   is ~3 kB per array here; correctness is worth more.
!
! * EVERY GETTER TAKES A LENGTH AND REFUSES RATHER THAN OVERRUNNING.  A negative
!   return means "your buffer is too small, I wrote nothing".  This is the one
!   memory-safety property a Julia caller cannot check on our behalf: ccall hands
!   over a bare pointer, and a Fortran routine that writes n elements into an
!   n-1-element array corrupts the host heap with no diagnostic anywhere.
!
! What this ABI does NOT give you, stated here because a caller reading only the
! signatures would assume otherwise:
!
! * It is not exception-safe against the whole tree.  Phase 3 converted the
!   reachable input-validation `stop`s in RDINP (rdinp.f90, consistency.f90); the
!   ~130 deeper `stop`/`par_stop` sites and the 109 `CALL Error(...)` clients still
!   terminate the process.  A malformed feff.inp is contained; a malformed
!   *structure* that survives rdinp and dies in pot may not be.  See
!   PHASE3_STATUS_AND_PLAN.md for the list.
! * It is not thread-safe.  One call at a time per process, period.
! * It is EXAFS only, and captures only the unpolarized chi.dat/xmu.dat pair.
!
! Naming: bind(c, name='...') on every entry, so the exported symbol is exactly
! what a C header declares -- no gfortran trailing underscore, no ifort case
! differences, nothing for Phase 4's ccall to guess about.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      module feff_capi

      use iso_c_binding
      use feff_status, only: feff_status_clear, feff_status_code,        &
     &     feff_status_message, feff_abort_code, feff_failed,            &
     &     feff_status_note,                                            &
     &     FEFF_OK, FEFF_ERR_WORKDIR, FEFF_ERR_NODATA, FEFF_ERR_BUFFER
      use feff_results

      implicit none

!     Bump on any change that a compiled caller could notice: a new entry point, a
!     changed signature, a changed status code, a changed column meaning.  Phase 4
!     checks this at load time so a stale libfeff.so is a clear error message
!     rather than a segfault in a getter.
!
!     Not named FEFF_ABI_VERSION: Fortran is case-insensitive, so that spelling is
!     the same identifier as the feff_abi_version() function below and gfortran
!     rejects the module outright ("has an explicit interface from a previous
!     declaration").
!     2 (Phase 4 step 3): added feff_get_npaths_stored, feff_get_path_ne,
!       feff_get_path_info, feff_get_path_rat, feff_get_path_columns.  Purely
!       additive -- every version-1 entry point keeps its signature and meaning --
!       but bumped anyway, because a caller compiled against 2 and loading a
!       version-1 library would find the new symbols missing, and a link error at
!       first call is a worse diagnosis than a version check at load.
!     3 (Phase 5): added feff_set_write_path_files, feff_get_write_path_files.
!       Additive in the same sense as 2, and the default preserves stock behaviour
!       (files are written unless a caller opts out), so a version-2 caller against
!       a version-3 library behaves identically.  Bumped for the same reason: a
!       version-3 caller against a version-2 library would miss the symbols.
      integer(c_int), parameter :: abi_version_number = 3

!     Longest path feff_exafs_run will accept.  PATH_MAX on Linux is 4096; this is
!     the buffer the C string is copied into before being handed to chdir.
      integer, parameter :: max_path = 4096

!     POSIX directory handling.  Fortran 2008 has no standard chdir/getcwd, and
!     gfortran's chdir/getcwd extensions are not available under every compiler
!     this tree is built with (ifort spells them differently), so bind to libc
!     directly -- which is also what makes the behaviour identical across the two
!     toolchains the gates compare.
      interface
         function c_chdir(path) bind(c, name='chdir')
         import :: c_int, c_char
         character(kind=c_char), dimension(*), intent(in) :: path
         integer(c_int) :: c_chdir
         end function c_chdir

         function c_getcwd(buf, size) bind(c, name='getcwd')
         import :: c_ptr, c_char, c_size_t
         character(kind=c_char), dimension(*), intent(inout) :: buf
         integer(c_size_t), value :: size
         type(c_ptr) :: c_getcwd
         end function c_getcwd
      end interface

      contains

!-----------------------------------------------------------------------
!     int feff_abi_version(void);
!-----------------------------------------------------------------------
      function feff_abi_version() bind(c, name='feff_abi_version')      &
     &         result(v)
      integer(c_int) :: v
      v = abi_version_number
      return
      end function feff_abi_version

!-----------------------------------------------------------------------
!     int feff_exafs_run(const char *workdir);
!
!     Runs rdinp -> atomic -> pot -> xsph -> fms -> path -> genfmt -> ff2x on
!     <workdir>/feff.inp, leaving the usual output files in <workdir>.  Returns 0
!     on success, or one of the FEFF_ERR_* codes; feff_last_error gives the text.
!
!     workdir may be NULL or the empty string, meaning "run in the current
!     directory" -- which keeps the Phase-2 gate's contract reachable and makes
!     the simplest possible call site work.
!
!     NAMED feff_exafs_run, NOT feff_run_exafs, and the difference is not
!     bikeshedding: Fortran puts bind(c) labels and procedure names in one global
!     namespace, so `bind(c, name='feff_run_exafs')` in a module that also does
!     `call feff_run_exafs` is a hard compile error --
!       "Global binding name 'feff_run_exafs' is already being used as a FUNCTION"
!     The obvious fix, renaming the Phase-1 Fortran driver, is worse: the frozen
!     Phase-2 gate asserts `feff_run_exafs_` is exported (check A) and its
!     reentrancy matrix calls that symbol directly, so renaming it would mean
!     editing a gate that currently certifies 32/32 -- exactly the thing a gate
!     exists to prevent.  So the ABI takes the new spelling and the internal
!     Fortran subroutine keeps the old one.  Worth collapsing to one name in Phase
!     4, once the Phase-2 gate can be retired in favour of this one.
!-----------------------------------------------------------------------
      function feff_run_exafs_c(workdir) bind(c, name='feff_exafs_run') &
     &         result(status)
      type(c_ptr), value, intent(in) :: workdir
      integer(c_int) :: status

      character(len=max_path) :: fdir, savedir
      logical :: moved
      integer :: rc

!     Clear at the START of the run, not the end.  A caller that ignores run N's
!     status must still get a truthful answer about run N+1, and clearing on exit
!     would mean the status is only readable in the window before the next call.
      call feff_status_clear
      call feff_results_clear

      moved = .false.
      savedir = ' '

      call c_string_to_fortran(workdir, fdir)

      if (len_trim(fdir) .gt. 0) then
!        Save where the caller was BEFORE moving, and refuse to move at all if we
!        cannot -- a chdir we cannot undo is worse than not running, because the
!        host would silently continue in a directory it never chose.
         if (.not. get_cwd(savedir)) then
            call feff_abort_code(FEFF_ERR_WORKDIR,                      &
     &           'could not read the current directory; refusing to chdir')
            status = feff_status_code()
            return
         endif

         rc = c_chdir(trim(fdir) // c_null_char)
         if (rc .ne. 0) then
            call feff_abort_code(FEFF_ERR_WORKDIR,                      &
     &           'could not chdir to workdir: ' // trim(fdir))
            status = feff_status_code()
            return
         endif
         moved = .true.
      endif

!     The chain itself.  It checks feff_failed() between stages, so an aborted
!     rdinp does not lead to atomic running on a previous run's mod*.inp.
      call feff_run_exafs

!     Restore unconditionally.  This is the only reason `moved` exists: on the
!     error paths above we had not moved yet, and chdir'ing to a blank savedir
!     would be a bug on the way out of reporting a different bug.
      if (moved) then
         rc = c_chdir(trim(savedir) // c_null_char)
         if (rc .ne. 0) then
!           The run may well have succeeded, but the host's cwd is now wrong and
!           that is not something to return 0 about -- every subsequent relative
!           path in the host program resolves somewhere unintended.  Report it,
!           but only if the run had not already failed for a better reason (first
!           abort wins, so this cannot mask the real cause).
            call feff_abort_code(FEFF_ERR_WORKDIR,                      &
     &           'ran, but could not restore the caller''s directory: ' &
     &           // trim(savedir))
         endif
      endif

      status = feff_status_code()
      return
      end function feff_run_exafs_c

!-----------------------------------------------------------------------
!     int feff_last_error(char *buf, int len);
!
!     Copies the message for the most recent failure into buf as a NUL-terminated
!     C string, truncating if len is short, and returns the number of characters
!     written excluding the NUL.  Returns 0 when there is no message, and -1 if
!     buf is NULL or len < 1.
!
!     Deliberately does not clear the message: a caller may want to read it more
!     than once (log it, then raise it), and clearing on read makes the second
!     read silently empty.
!-----------------------------------------------------------------------
      function feff_last_error_c(buf, len) bind(c, name='feff_last_error') &
     &         result(n)
      type(c_ptr), value, intent(in) :: buf
      integer(c_int), value, intent(in) :: len
      integer(c_int) :: n

      character(kind=c_char), pointer :: cbuf(:)
      character(len=1024) :: msg
      integer :: i, ncopy

      n = -1
      if (.not. c_associated(buf)) return
      if (len .lt. 1) return

      call feff_status_message(msg)

      call c_f_pointer(buf, cbuf, [int(len)])

      ncopy = min(len_trim(msg), int(len) - 1)
      do i = 1, ncopy
         cbuf(i) = msg(i:i)
      enddo
      cbuf(ncopy + 1) = c_null_char

      n = ncopy
      return
      end function feff_last_error_c

!-----------------------------------------------------------------------
!     int feff_get_nk(void);
!
!     Number of fine-grid points the last run produced, i.e. how long the arrays
!     handed to feff_get_chi / feff_get_xmu must be.  0 means no run in this
!     process has produced spectra, which is a distinct answer from "a run failed"
!     -- for that, check the status feff_exafs_run returned.
!-----------------------------------------------------------------------
      function feff_get_nk_c() bind(c, name='feff_get_nk') result(n)
      integer(c_int) :: n
      n = int(res_nk, c_int)
      return
      end function feff_get_nk_c

!-----------------------------------------------------------------------
!     int feff_get_npaths(void);      /* paths that survived the importance cut */
!     int feff_get_npaths_total(void); /* paths listed in list.dat */
!
!     The two halves of chi.dat's "N/M paths used" header line.
!-----------------------------------------------------------------------
      function feff_get_npaths_c() bind(c, name='feff_get_npaths')      &
     &         result(n)
      integer(c_int) :: n
      n = int(res_npaths_used, c_int)
      return
      end function feff_get_npaths_c

      function feff_get_npaths_total_c()                                &
     &         bind(c, name='feff_get_npaths_total') result(n)
      integer(c_int) :: n
      n = int(res_npaths_total, c_int)
      return
      end function feff_get_npaths_total_c

!-----------------------------------------------------------------------
!     int feff_get_chi(double *k, double *chi, double *mag, double *phase, int n);
!
!     chi.dat's four columns, unrounded.  Returns the number of points written, or
!     a negative FEFF_ERR_* code on refusal.  Any pointer may be NULL to skip that
!     column, so a caller that only wants k and chi does not have to allocate the
!     other two.
!-----------------------------------------------------------------------
      function feff_get_chi_c(k, chi, mag, phase, n)                    &
     &         bind(c, name='feff_get_chi') result(nw)
      type(c_ptr), value, intent(in) :: k, chi, mag, phase
      integer(c_int), value, intent(in) :: n
      integer(c_int) :: nw

      nw = check_getter(res_have_chi, n)
      if (nw .lt. 0) return

      call copy_out(k,     res_k,     res_nk)
      call copy_out(chi,   res_chi,   res_nk)
      call copy_out(mag,   res_mag,   res_nk)
      call copy_out(phase, res_phase, res_nk)

      nw = int(res_nk, c_int)
      return
      end function feff_get_chi_c

!-----------------------------------------------------------------------
!     int feff_get_xmu(double *omega, double *e, double *k,
!                      double *mu, double *mu0, double *chi, int n);
!
!     xmu.dat's six columns, unrounded, same conventions as feff_get_chi.
!-----------------------------------------------------------------------
      function feff_get_xmu_c(omega, e, k, mu, mu0, chi, n)             &
     &         bind(c, name='feff_get_xmu') result(nw)
      type(c_ptr), value, intent(in) :: omega, e, k, mu, mu0, chi
      integer(c_int), value, intent(in) :: n
      integer(c_int) :: nw

      nw = check_getter(res_have_xmu, n)
      if (nw .lt. 0) return

      call copy_out(omega, res_omega, res_nk)
      call copy_out(e,     res_e,     res_nk)
      call copy_out(k,     res_xk,    res_nk)
      call copy_out(mu,    res_mu,    res_nk)
      call copy_out(mu0,   res_mu0,   res_nk)
      call copy_out(chi,   res_xchi,  res_nk)

      nw = int(res_nk, c_int)
      return
      end function feff_get_xmu_c

!-----------------------------------------------------------------------
!     Per-path getters (feffNNNN.dat).  feffjl Phase 4 step 3.
!
!     These exist because the consumer of this ABI reconstructs chi(k) per path
!     rather than re-running FEFF: it needs reff/deg/nleg/rat plus the seven
!     columns, and today it gets them by parsing feffNNNN.dat off disk.
!
!     Two properties a caller must know, both documented at length in
!     m_feff_results.f90 and repeated in gates/feff.h:
!
!       * The values carry only ~7 significant figures of ACCURACY.  feff.bin's
!         round trip (rdfbin.f90:89 reads `real achi`) rounds the input to single
!         before feffdt sees it.  The stored numbers are still genuine doubles --
!         feffdt does double arithmetic on them, so they do not round-trip through
!         float32 -- but ~1e-7 relative is the honest error bar, not the
!         full-double property feff_get_chi/feff_get_xmu have.
!       * The amplitudes are PRE-Debye-Waller and PRE-s02, because feffdt runs
!         before dwadd.  That is what a caller applying its own s02/sigma2/degen
!         wants.
!
!     AVAILABILITY IS REPORTED, NOT FORCED.  feffdt is only called when ipr6 >= 3
!     (ff2chi.f90:171, fed from the 6th PRINT field -- the *sixth*, despite the
!     variable being spelled ipr4 in ff2chi's argument list, because ff2x.f90:81
!     passes ipr6 into that dummy).  The ABI deliberately does not set the flag
!     behind the caller's back: that would change which files land in the working
!     directory and make a getter's availability depend on something never asked
!     for.  Instead feff_get_npaths_stored() returns 0 and feff_last_error says why.
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!     int feff_get_npaths_stored(void);
!
!     Number of paths whose per-path data was captured, i.e. the valid range of the
!     `ip` argument below (1-based).  0 means no per-path data: either no run has
!     completed ff2x, or the run did not have PRINT flag 6 >= 3.  Sets the error
!     message to whichever it was, so a caller can tell them apart.
!-----------------------------------------------------------------------
      function feff_get_npaths_stored_c()                                &
     &         bind(c, name='feff_get_npaths_stored') result(n)
      integer(c_int) :: n

      n = 0
      if (res_have_paths) then
         n = int(res_npaths_stored, c_int)
         return
      endif

!     Not an abort -- 0 is a legitimate answer to "how many paths do you have",
!     and a caller checking availability should not have to clear a failed status
!     afterwards.  But the message is set, because "0" alone does not say which of
!     the two causes applies.
      if (res_nk .le. 0) then
         call feff_status_note(                                          &
     &        'no per-path data: no run has completed ff2x in this process')
      else
         call feff_status_note(                                          &
     &        'no per-path data: feffdt did not run; set PRINT field 6 to 3 or 4')
      endif

      return
      end function feff_get_npaths_stored_c

!-----------------------------------------------------------------------
!     int feff_get_path_ne(void);
!
!     Length of the per-path columns -- the n to pass to feff_get_path_columns.
!
!     This is NOT feff_get_nk().  The per-path data is on genfmt's energy grid
!     (ff2chi's ne1) while chi.dat is on the interpolated fine grid; on the cu
!     fixture that is 63 versus 401.  A caller that reused nk here would ask for
!     six times the data that exists, which is exactly the buffer-size confusion
!     the separate getter prevents.
!-----------------------------------------------------------------------
      function feff_get_path_ne_c() bind(c, name='feff_get_path_ne')     &
     &         result(n)
      integer(c_int) :: n
      n = 0
      if (res_have_paths) n = int(res_pne, c_int)
      return
      end function feff_get_path_ne_c

!-----------------------------------------------------------------------
!     int feff_get_path_info(int ip, int *index, int *nleg,
!                            double *deg, double *reff, double *crit);
!
!     One path's header scalars.  ip is 1-based and is the path's position in write
!     order; *index is the NNNN in feffNNNN.dat, which is the path's own id and is
!     a different number.  reff is in Angstrom.  Any pointer may be NULL.
!
!     Returns FEFF_OK, or a negative FEFF_ERR_* -- -FEFF_ERR_NODATA if there is no
!     per-path data, -FEFF_ERR_BUFFER if ip is out of range.  An out-of-range index
!     is a buffer error rather than a silent zero for the same reason a short array
!     is: it is a caller bug, and returning plausible zeros hides it.
!-----------------------------------------------------------------------
      function feff_get_path_info_c(ip, idx, nleg, deg, reff, crit)      &
     &         bind(c, name='feff_get_path_info') result(rc)
      integer(c_int), value, intent(in) :: ip
      type(c_ptr), value, intent(in) :: idx, nleg, deg, reff, crit
      integer(c_int) :: rc

      rc = check_path_getter(ip)
      if (rc .lt. 0) return

      call copy_out_int(idx,  res_pindex(ip))
      call copy_out_int(nleg, res_pnleg(ip))
      call copy_out_one(deg,  res_pdeg(ip))
      call copy_out_one(reff, res_preff(ip))
      call copy_out_one(crit, res_pcrit(ip))

      rc = int(FEFF_OK, c_int)
      return
      end function feff_get_path_info_c

!-----------------------------------------------------------------------
!     int feff_get_path_rat(int ip, double *rat, int *ipot, int nleg);
!
!     Leg coordinates for path ip, in Angstrom, written as 3*nleg doubles in
!     column-major (x,y,z) per leg -- i.e. rat[3*(ileg-1)+0..2], which is the same
!     memory layout a Fortran rat(3,nleg) has and what Julia reshapes to (3,nleg)
!     with no permutedims.
!
!     ipot receives nleg potential indices.  Either pointer may be NULL.
!
!     nleg must be at least the path's own nleg (from feff_get_path_info); short
!     is refused with -FEFF_ERR_BUFFER and nothing is written.  Legs are indexed as
!     FEFF indexes them, NOT in feffNNNN.dat's print order -- the file prints the
!     absorbing atom (leg nleg) first and then legs 1..nleg-1, which is a
!     presentation choice this getter does not reproduce.  Returns the number of
!     legs written, or a negative FEFF_ERR_*.
!-----------------------------------------------------------------------
      function feff_get_path_rat_c(ip, rat, ipotout, nleg)               &
     &         bind(c, name='feff_get_path_rat') result(nw)
      integer(c_int), value, intent(in) :: ip, nleg
      type(c_ptr), value, intent(in) :: rat, ipotout
      integer(c_int) :: nw

      real(c_double), pointer :: p(:)
      integer(c_int), pointer :: q(:)
      integer :: nl, ileg, j

      nw = check_path_getter(ip)
      if (nw .lt. 0) return

      nl = res_pnleg(ip)
      if (nl .lt. 1 .or. nl .gt. res_plegtot) then
         call feff_abort_code(FEFF_ERR_NODATA,                           &
     &        'stored path has a nonsensical leg count')
         nw = -int(FEFF_ERR_NODATA, c_int)
         return
      endif

      if (nleg .lt. nl) then
         call feff_abort_code(FEFF_ERR_BUFFER,                           &
     &        'caller buffer too small for this path''s legs; ' //       &
     &        'call feff_get_path_info first')
         nw = -int(FEFF_ERR_BUFFER, c_int)
         return
      endif

      if (c_associated(rat)) then
         call c_f_pointer(rat, p, [3*nl])
         do ileg = 1, nl
            do j = 1, 3
               p(3*(ileg-1) + j) = res_prat(j,ileg,ip)
            enddo
         enddo
      endif

      if (c_associated(ipotout)) then
         call c_f_pointer(ipotout, q, [nl])
         do ileg = 1, nl
            q(ileg) = int(res_pipot(ileg,ip), c_int)
         enddo
      endif

      nw = int(nl, c_int)
      return
      end function feff_get_path_rat_c

!-----------------------------------------------------------------------
!     int feff_get_path_columns(int ip, double *k, double *phc, double *mag,
!                               double *phase, double *redfac, double *lambda,
!                               double *realp, int n);
!
!     feffNNNN.dat's seven columns for path ip, in file order:
!       k [1/Ang], real[2*phc], mag[feff], phase[feff], red factor,
!       lambda [Ang], real[p] [1/Ang].
!
!     Same conventions as feff_get_chi: any pointer may be NULL to skip that
!     column, n must be at least feff_get_path_ne(), and a short n is refused with
!     -FEFF_ERR_BUFFER having written nothing.  Returns the number of points
!     written.
!-----------------------------------------------------------------------
      function feff_get_path_columns_c(ip, k, phc, mag, phase, redfac,   &
     &         xlambda, realp, n)                                        &
     &         bind(c, name='feff_get_path_columns') result(nw)
      integer(c_int), value, intent(in) :: ip, n
      type(c_ptr), value, intent(in) :: k, phc, mag, phase, redfac,      &
     &     xlambda, realp
      integer(c_int) :: nw

      nw = check_path_getter(ip)
      if (nw .lt. 0) return

      if (n .lt. res_pne) then
         call feff_abort_code(FEFF_ERR_BUFFER,                           &
     &        'caller buffer too small for the path columns; ' //        &
     &        'call feff_get_path_ne first')
         nw = -int(FEFF_ERR_BUFFER, c_int)
         return
      endif

      call copy_out(k,       res_pk(:,ip),      res_pne)
      call copy_out(phc,     res_pphc(:,ip),    res_pne)
      call copy_out(mag,     res_pmag(:,ip),    res_pne)
      call copy_out(phase,   res_pphase(:,ip),  res_pne)
      call copy_out(redfac,  res_predfac(:,ip), res_pne)
      call copy_out(xlambda, res_plambda(:,ip), res_pne)
      call copy_out(realp,   res_prealp(:,ip),  res_pne)

      nw = int(res_pne, c_int)
      return
      end function feff_get_path_columns_c

!-----------------------------------------------------------------------
!     void feff_set_write_path_files(int on);
!
!     Ask feffdt to write feffNNNN.dat and files.dat (on /= 0, the default) or to
!     capture the per-path data without writing anything (on == 0).
!
!     This is a caller preference and NOT part of the run results, so it survives
!     feff_exafs_run's clear-at-start and stays in effect until changed or the
!     process exits.  Setting it does not need a run to have happened.
!
!     Turning writing off does not change any captured value: feffdt computes every
!     column and calls the store routines either way, so the getters return the
!     same numbers with or without files on disk.  That equality is what makes the
!     flag safe to flip in a fitting loop, and it is asserted rather than assumed.
!
!     No status code: there is nothing to fail.  A void return also means a caller
!     linked against a version-2 library gets a link error at the call rather than
!     a plausible-looking status it might ignore.
!-----------------------------------------------------------------------
      subroutine feff_set_write_path_files_c(on)                         &
     &         bind(c, name='feff_set_write_path_files')
      integer(c_int), value, intent(in) :: on
      call feff_results_set_write_path_files(on .ne. 0_c_int)
      return
      end subroutine feff_set_write_path_files_c

!-----------------------------------------------------------------------
!     int feff_get_write_path_files(void);
!
!     1 when feffdt will write its files, 0 when it will only capture.  Reads the
!     library's own state rather than echoing the caller's last argument, so a
!     host talking to a stale libfeff.so finds out here instead of by wondering
!     why the files it asked to suppress are still on disk.
!-----------------------------------------------------------------------
      function feff_get_write_path_files_c()                             &
     &         bind(c, name='feff_get_write_path_files') result(on)
      integer(c_int) :: on
      if (feff_results_get_write_path_files()) then
         on = 1_c_int
      else
         on = 0_c_int
      endif
      return
      end function feff_get_write_path_files_c

!=======================================================================
!     Internals.  Not bind(c) and not exported as API.
!=======================================================================

!     Shared precondition check for the per-path getters: data present, ip in
!     range.  Mirrors check_getter's contract -- negative return, -code is the
!     reason.
      function check_path_getter(ip) result(rc)
      integer(c_int), intent(in) :: ip
      integer(c_int) :: rc

      if (.not. res_have_paths .or. res_npaths_stored .le. 0 .or.        &
     &    res_pne .le. 0) then
         call feff_abort_code(FEFF_ERR_NODATA,                           &
     &        'no per-path data: feffdt did not run ' //                 &
     &        '(set PRINT field 6 to 3 or 4), or no run completed ff2x')
         rc = -int(FEFF_ERR_NODATA, c_int)
         return
      endif

      if (ip .lt. 1 .or. ip .gt. res_npaths_stored) then
         call feff_abort_code(FEFF_ERR_BUFFER,                           &
     &        'path index out of range; valid range is 1..' //           &
     &        'feff_get_npaths_stored()')
         rc = -int(FEFF_ERR_BUFFER, c_int)
         return
      endif

      rc = 0
      return
      end function check_path_getter

!     Copy a single double / int out, skipping NULL.  Separate from copy_out
!     because the scalar getters hand back one value per pointer rather than an
!     array, and reusing copy_out would mean building a size-1 array per call.
      subroutine copy_out_one(dst, val)
      type(c_ptr), value, intent(in) :: dst
      real*8, intent(in) :: val
      real(c_double), pointer :: p
      if (.not. c_associated(dst)) return
      call c_f_pointer(dst, p)
      p = val
      return
      end subroutine copy_out_one

      subroutine copy_out_int(dst, val)
      type(c_ptr), value, intent(in) :: dst
      integer, intent(in) :: val
      integer(c_int), pointer :: p
      if (.not. c_associated(dst)) return
      call c_f_pointer(dst, p)
      p = int(val, c_int)
      return
      end subroutine copy_out_int

!     Shared precondition check for the getters.  Returns a negative code, so a
!     caller can treat "< 0" as failure and -code as the reason.
      function check_getter(have, n) result(rc)
      logical, intent(in) :: have
      integer(c_int), intent(in) :: n
      integer(c_int) :: rc

      if (.not. have .or. res_nk .le. 0) then
         call feff_abort_code(FEFF_ERR_NODATA,                          &
     &        'no spectrum available: no run has completed ff2x in this process')
         rc = -int(FEFF_ERR_NODATA, c_int)
         return
      endif

!     Refuse rather than truncate.  A short buffer is a caller bug -- silently
!     writing n of res_nk points would hand back a spectrum that looks valid and
!     is quietly cut off, which is harder to diagnose than an error return.
      if (n .lt. res_nk) then
         call feff_abort_code(FEFF_ERR_BUFFER,                          &
     &        'caller buffer too small for the spectrum; call feff_get_nk first')
         rc = -int(FEFF_ERR_BUFFER, c_int)
         return
      endif

      rc = 0
      return
      end function check_getter

!     Copy n doubles into a caller array, skipping a NULL pointer.  The length has
!     already been checked by check_getter; this routine assumes that and does not
!     re-check, which is why it is private.
      subroutine copy_out(dst, src, n)
      type(c_ptr), value, intent(in) :: dst
      real*8, intent(in) :: src(:)
      integer, intent(in) :: n

      real(c_double), pointer :: p(:)

      if (.not. c_associated(dst)) return
      call c_f_pointer(dst, p, [n])
      p(1:n) = src(1:n)

      return
      end subroutine copy_out

!     Copy a NUL-terminated C string into a blank-padded Fortran string.  A NULL
!     pointer yields a blank result, which is how "run in the current directory"
!     is spelled.  Truncates at max_path rather than reading past the buffer if the
!     caller passes something unterminated and enormous.
      subroutine c_string_to_fortran(cptr, f)
      type(c_ptr), value, intent(in) :: cptr
      character(len=*), intent(out) :: f

      character(kind=c_char), pointer :: chars(:)
      integer :: i

      f = ' '
      if (.not. c_associated(cptr)) return

      call c_f_pointer(cptr, chars, [len(f)])
      do i = 1, len(f)
         if (chars(i) .eq. c_null_char) return
         f(i:i) = chars(i)
      enddo

      return
      end subroutine c_string_to_fortran

!     getcwd into a Fortran string.  .false. means the call failed, in which case f
!     is left blank -- callers must not chdir to it.
      function get_cwd(f) result(ok)
      character(len=*), intent(out) :: f
      logical :: ok

      character(kind=c_char) :: buf(max_path)
      type(c_ptr) :: p
      integer :: i

      f = ' '
      ok = .false.

      p = c_getcwd(buf, int(max_path, c_size_t))
      if (.not. c_associated(p)) return

      do i = 1, min(max_path, len(f))
         if (buf(i) .eq. c_null_char) exit
         f(i:i) = buf(i)
      enddo

      ok = (len_trim(f) .gt. 0)
      return
      end function get_cwd

      end module feff_capi
