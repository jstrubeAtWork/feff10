!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! feffjl Phase 3: in-memory copy of the spectra a run produced.
!
! Every handoff in FEFF is a file, including the final answer: ff2x writes
! chi.dat and xmu.dat and the chain ends.  For a fit loop that is the wrong shape
! twice over -- the caller pays a format/parse round trip per iteration, and the
! numbers it gets back are the 6-7 significant figures the format statement
! allowed, not the doubles that were computed.
!
! So capture at WRITE time rather than re-reading our own text output.  The
! alternative considered was a reader for chi.dat/xmu.dat in the C ABI, which is
! less code but strictly worse: it re-derives what we already had in registers,
! it silently inherits any formatting change, and it cannot tell "the run failed
! before writing" from "the file is left over from a previous run" -- exactly the
! confusion the ABI exists to remove.  Capturing in place makes a getter's answer
! provably the run that just happened, because it was stored by the same statement
! that printed it.
!
! The stored values are the write statement's own expressions, unrounded.  A
! getter therefore agrees with the file to the file's printed precision and is
! more accurate beyond it.  The gate compares the two that way round.
!
! Storage lives here rather than in COMMON/m_feff_capi.f90 for the same reason
! COMMON/m_feff_status.f90 does: FF2X/ff2chi.f90 must not acquire a dependency on
! iso_c_binding, and the standalone executables must keep compiling unchanged.
! In an executable this module simply holds arrays nobody reads.
!
! Only the EXAFS pair is captured -- iip=1 (chi.dat / xmu.dat) with
! iabs.eq.nabs.  The polarization-resolved chiNN.dat / xmuNN.dat variants of the
! ELNES/NRIXS paths are out of scope for Phase 3, and configurational averaging
! (nabs>1) is untested through the in-process driver anyway (limitation 4).
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      module feff_results

      implicit none

!     Number of fine-grid points actually stored, i.e. ff2chi's nkx.  Zero means
!     "no run has produced spectra in this process", which is what a getter
!     reports as FEFF_ERR_NODATA rather than handing back a stale or empty array.
      integer :: res_nk = 0

!     chi.dat columns, in file order: k [1/Ang], chi, |chi|, phase.
      real*8, allocatable :: res_k(:)
      real*8, allocatable :: res_chi(:)
      real*8, allocatable :: res_mag(:)
      real*8, allocatable :: res_phase(:)

!     xmu.dat columns, in file order: omega [eV], e [eV], k [1/Ang], mu, mu0, chi.
!     res_xk is xmu.dat's own k column.  It is the same expression as res_k in the
!     EXAFS path, and is stored separately anyway so that a getter never has to
!     assume the two files share a grid -- they are written by two different loops.
      real*8, allocatable :: res_omega(:)
      real*8, allocatable :: res_e(:)
      real*8, allocatable :: res_xk(:)
      real*8, allocatable :: res_mu(:)
      real*8, allocatable :: res_mu0(:)
      real*8, allocatable :: res_xchi(:)

!     Set only after the corresponding write loop has run to completion, so a run
!     that dies midway through ff2chi reports no data rather than half a spectrum.
      logical :: res_have_chi = .false.
      logical :: res_have_xmu = .false.

!     The "N/M paths used" pair from the chi.dat/xmu.dat header: res_npaths_used is
!     ff2chi's `nused` (paths surviving the curved-wave importance cut in dwadd),
!     res_npaths_total is `ntotal` (paths listed in list.dat).  A fit that watches
!     `used` drift between iterations is watching its own path filter change, which
!     is worth being able to see without parsing a header line.
      integer :: res_npaths_used  = 0
      integer :: res_npaths_total = 0

!=======================================================================
!     Per-path results (feffNNNN.dat).  feffjl Phase 4 step 3.
!
!     Same capture-at-write-time approach as the spectra above, and for the same
!     reason -- but with one honest difference that the header comment's "full
!     doubles the format truncated" argument does NOT cover, so it is stated here
!     rather than left for a caller to discover:
!
!     THE PER-PATH AMPLITUDES CARRY ONLY SINGLE-PRECISION ACCURACY.
!     GENFMT/genfmtsub.f90 computes cchi/amff/phff in complex*16, but writes them
!     to feff.bin through wrpadd, and FF2X/rdfbin.f90:89 reads them back into
!     `real achi(nex,npx)` / `phchi` -- declared single.  So ~7 significant figures
!     is all the INPUT carries by the time feffdt sees it.
!
!     Note the precise claim, because it is easy to overstate: the stored values are
!     not float32 bit patterns widened to double.  feffdt does real double-precision
!     arithmetic on those single-precision inputs (cdelt + l0*pi, abs(cfms)*bohr),
!     so the results have doubles' full 17 digits and do not round-trip through
!     float32 unchanged -- measured, only 0.8% of them do.  What is limited is the
!     ACCURACY, not the representation: the trailing digits are a faithful double
!     computed from an input that was already rounded to ~1e-7 relative.  A caller
!     should treat ~1e-7 as the error bar and must not read agreement to 1e-15 as
!     evidence of anything.  Capturing at write time still
!     beats parsing feffNNNN.dat (no format truncation stacked on top of the
!     precision loss, no file I/O, no stale-file ambiguity), but it does not deliver
!     the full-double property claimed for chi/xmu, and gates/feff.h says so.
!     Capturing upstream in genfmtsub, where the doubles still exist, is Phase 5:
!     it is a second capture site in another stage, it has to survive the
!     ipr3/crit0 path filter, and feffdt's bohr conversions and pijump phase
!     unwrapping would have to move with it.
!
!     The amplitudes are also PRE-Debye-Waller and PRE-s02: feffdt is called from
!     ff2chi.f90:172 and dwadd -- which multiplies achi by the DW factor, s02 and
!     deg -- does not run until line 304.  That is what a caller applying its own
!     s02/sigma2/degen needs, and it is a load-bearing ordering rather than a
!     coincidence: moving the feffdt call after dwadd would make every such caller
!     double-apply both.  The Phase-4 gate asserts it rather than trusting a
!     comment.
!
!     Sized at capture time from the actual (ne, npaths), not from the dimsmod
!     maxima: nex=2000 by npx_ff2x=2000 by seven columns would be 224 MB of mostly
!     zeros.
!=======================================================================

!     Grid length and path count actually stored.  res_pne is feffdt's `ne`, which
!     is ff2chi's ne1 -- the genfmt energy grid.  It is NOT res_nk: chi.dat's fine
!     grid is interpolated onto a different, longer mesh (401 vs 63 on the cu
!     fixture).  Kept as its own variable so no getter can assume one length.
      integer :: res_pne     = 0
      integer :: res_npaths_stored = 0

!     Per-path scalars, indexed 1..res_npaths_stored in feffdt's own write order
!     (list.dat order), so path i here is the i'th feffNNNN.dat written.
!     res_pindex is the NNNN in that filename -- the path's own id, which is not
!     the same as its position, and is what a caller needs to correlate with
!     files.dat or paths.dat.
      integer, allocatable :: res_pindex(:)
      integer, allocatable :: res_pnleg(:)
      real*8,  allocatable :: res_pdeg(:)
      real*8,  allocatable :: res_preff(:)
      real*8,  allocatable :: res_pcrit(:)

!     Leg coordinates, (3, legtot, npaths), in Angstrom -- feffdt writes
!     rat*bohr, and the stored value is that same converted expression, so a getter
!     and the file agree in units as well as value.
      real*8, allocatable :: res_prat(:,:,:)
      integer, allocatable :: res_pipot(:,:)
      integer :: res_plegtot = 0

!     The seven feffNNNN.dat columns, (ne, npaths), in file order:
!     k, real[2*phc], mag[feff], phase[feff], red factor, lambda, real[p].
      real*8, allocatable :: res_pk(:,:)
      real*8, allocatable :: res_pphc(:,:)
      real*8, allocatable :: res_pmag(:,:)
      real*8, allocatable :: res_pphase(:,:)
      real*8, allocatable :: res_predfac(:,:)
      real*8, allocatable :: res_plambda(:,:)
      real*8, allocatable :: res_prealp(:,:)

!     Set only once feffdt's outer path loop has completed, so a run that dies
!     partway through reports no per-path data rather than a subset that looks
!     complete.
      logical :: res_have_paths = .false.

      contains

!     Size the buffers for n fine-grid points.  Extent test then deallocate, the
!     same shape as the Phase-1a *_allocate routines in COMMON/m_inpmodules.f90
!     and the Phase-3 fix in KSPACE/m_struct.f90: a second run with a different
!     grid length must resize, and a bare `.not.allocated` guard cannot tell
!     "already the right size" from "already the wrong size".
      subroutine feff_results_alloc(n)
      integer, intent(in) :: n

      if (allocated(res_k)) then
         if (size(res_k).ne.n) call feff_results_dealloc
      endif

      if (.not.allocated(res_k)) then
         allocate(res_k(n), res_chi(n), res_mag(n), res_phase(n))
         allocate(res_omega(n), res_e(n), res_xk(n))
         allocate(res_mu(n), res_mu0(n), res_xchi(n))
      endif

!     Not res_nk: that is set by the store routines' own bookkeeping once the
!     loops finish.  Allocating is not the same as having data.
      res_k = 0.d0; res_chi = 0.d0; res_mag = 0.d0; res_phase = 0.d0
      res_omega = 0.d0; res_e = 0.d0; res_xk = 0.d0
      res_mu = 0.d0; res_mu0 = 0.d0; res_xchi = 0.d0

      return
      end subroutine feff_results_alloc

      subroutine feff_results_dealloc
      if (allocated(res_k))     deallocate(res_k)
      if (allocated(res_chi))   deallocate(res_chi)
      if (allocated(res_mag))   deallocate(res_mag)
      if (allocated(res_phase)) deallocate(res_phase)
      if (allocated(res_omega)) deallocate(res_omega)
      if (allocated(res_e))     deallocate(res_e)
      if (allocated(res_xk))    deallocate(res_xk)
      if (allocated(res_mu))    deallocate(res_mu)
      if (allocated(res_mu0))   deallocate(res_mu0)
      if (allocated(res_xchi))  deallocate(res_xchi)
      return
      end subroutine feff_results_dealloc

!     Called by the ABI at the START of a run, like feff_status_clear: a caller
!     that reads getters after a failed run must be told there is no data, not
!     handed the previous run's spectrum.  The buffers themselves are kept
!     allocated -- clearing the flags is what makes the data unreachable, and
!     holding the allocation avoids churning ~30 kB per fit iteration.
      subroutine feff_results_clear
      res_nk = 0
      res_have_chi = .false.
      res_have_xmu = .false.
      res_npaths_used  = 0
      res_npaths_total = 0
!     Per-path data too, and for the same reason: a run that fails, or that
!     succeeds with ipr6 < 3 after one that had it set, must report "no per-path
!     data" rather than the previous run's paths.  Buffers stay allocated.
      res_pne = 0
      res_npaths_stored = 0
      res_have_paths = .false.
      return
      end subroutine feff_results_clear

!     The chi.dat/xmu.dat header's path counts.
      subroutine feff_results_store_paths(nused, ntotal)
      integer, intent(in) :: nused, ntotal
      res_npaths_used  = nused
      res_npaths_total = ntotal
      return
      end subroutine feff_results_store_paths

!     One point of chi.dat.  Arguments are the write statement's expressions in
!     file column order.
      subroutine feff_results_store_chi(ik, k, chi, mag, phase)
      integer, intent(in) :: ik
      real*8, intent(in) :: k, chi, mag, phase

      if (.not.allocated(res_k)) return
      if (ik.lt.1 .or. ik.gt.size(res_k)) return

      res_k(ik)     = k
      res_chi(ik)   = chi
      res_mag(ik)   = mag
      res_phase(ik) = phase

      return
      end subroutine feff_results_store_chi

!     One point of xmu.dat, likewise in file column order.
      subroutine feff_results_store_xmu(ik, omega, e, k, mu, mu0, chi)
      integer, intent(in) :: ik
      real*8, intent(in) :: omega, e, k, mu, mu0, chi

      if (.not.allocated(res_omega)) return
      if (ik.lt.1 .or. ik.gt.size(res_omega)) return

      res_omega(ik) = omega
      res_e(ik)     = e
      res_xk(ik)    = k
      res_mu(ik)    = mu
      res_mu0(ik)   = mu0
      res_xchi(ik)  = chi

      return
      end subroutine feff_results_store_xmu

!     Called once each write loop has completed all nk points.  n is passed rather
!     than inferred so the flag cannot be set by a loop that exited early.
      subroutine feff_results_done_chi(n)
      integer, intent(in) :: n
      res_nk = n
      res_have_chi = .true.
      return
      end subroutine feff_results_done_chi

      subroutine feff_results_done_xmu(n)
      integer, intent(in) :: n
      res_nk = n
      res_have_xmu = .true.
      return
      end subroutine feff_results_done_xmu


!     Size the per-path buffers for ne grid points, np paths, nlegmax legs.
!     Same resize-on-extent-change shape as feff_results_alloc: a second run with a
!     different path count must not be handed the first run's arrays.
      subroutine feff_results_alloc_paths(ne, np, nlegmax)
      integer, intent(in) :: ne, np, nlegmax

      if (ne.le.0 .or. np.le.0 .or. nlegmax.le.0) return

      if (allocated(res_pk)) then
         if (size(res_pk,1).ne.ne .or. size(res_pk,2).ne.np .or.         &
     &       size(res_prat,2).ne.nlegmax) call feff_results_dealloc_paths
      endif

      if (.not.allocated(res_pk)) then
         allocate(res_pindex(np), res_pnleg(np), res_pdeg(np),           &
     &            res_preff(np), res_pcrit(np))
         allocate(res_prat(3,nlegmax,np), res_pipot(nlegmax,np))
         allocate(res_pk(ne,np), res_pphc(ne,np), res_pmag(ne,np),       &
     &            res_pphase(ne,np), res_predfac(ne,np),                 &
     &            res_plambda(ne,np), res_prealp(ne,np))
      endif

      res_pindex = 0; res_pnleg = 0
      res_pdeg = 0.d0; res_preff = 0.d0; res_pcrit = 0.d0
      res_prat = 0.d0; res_pipot = 0
      res_pk = 0.d0; res_pphc = 0.d0; res_pmag = 0.d0
      res_pphase = 0.d0; res_predfac = 0.d0
      res_plambda = 0.d0; res_prealp = 0.d0

!     Recorded now because the getters need the leg extent to copy rat out, but
!     NOT res_pne/res_npaths_stored: those are the "have data" bookkeeping and are
!     set by feff_results_done_paths once the loop finishes.
      res_plegtot = nlegmax

      return
      end subroutine feff_results_alloc_paths

      subroutine feff_results_dealloc_paths
      if (allocated(res_pindex))  deallocate(res_pindex)
      if (allocated(res_pnleg))   deallocate(res_pnleg)
      if (allocated(res_pdeg))    deallocate(res_pdeg)
      if (allocated(res_preff))   deallocate(res_preff)
      if (allocated(res_pcrit))   deallocate(res_pcrit)
      if (allocated(res_prat))    deallocate(res_prat)
      if (allocated(res_pipot))   deallocate(res_pipot)
      if (allocated(res_pk))      deallocate(res_pk)
      if (allocated(res_pphc))    deallocate(res_pphc)
      if (allocated(res_pmag))    deallocate(res_pmag)
      if (allocated(res_pphase))  deallocate(res_pphase)
      if (allocated(res_predfac)) deallocate(res_predfac)
      if (allocated(res_plambda)) deallocate(res_plambda)
      if (allocated(res_prealp))  deallocate(res_prealp)
      res_plegtot = 0
      return
      end subroutine feff_results_dealloc_paths

!     One path's header scalars.  ip is the position in the write order, not the
!     path id -- that is `idx`.  deg/reff/crit are single in feffdt (they come from
!     feff.bin), and reff is passed already multiplied by bohr, matching the file.
      subroutine feff_results_store_path_info(ip, idx, nleg, deg, reff,  &
     &           crit)
      integer, intent(in) :: ip, idx, nleg
      real*8, intent(in) :: deg, reff, crit

      if (.not.allocated(res_pindex)) return
      if (ip.lt.1 .or. ip.gt.size(res_pindex)) return

      res_pindex(ip) = idx
      res_pnleg(ip)  = nleg
      res_pdeg(ip)   = deg
      res_preff(ip)  = reff
      res_pcrit(ip)  = crit

      return
      end subroutine feff_results_store_path_info

!     One leg's coordinates and potential index, in Angstrom.
      subroutine feff_results_store_path_leg(ip, ileg, x, y, z, ipotl)
      integer, intent(in) :: ip, ileg, ipotl
      real*8, intent(in) :: x, y, z

      if (.not.allocated(res_prat)) return
      if (ip.lt.1 .or. ip.gt.size(res_prat,3)) return
      if (ileg.lt.1 .or. ileg.gt.size(res_prat,2)) return

      res_prat(1,ileg,ip) = x
      res_prat(2,ileg,ip) = y
      res_prat(3,ileg,ip) = z
      res_pipot(ileg,ip)  = ipotl

      return
      end subroutine feff_results_store_path_leg

!     One row of one path's feffNNNN.dat, arguments in file column order.
      subroutine feff_results_store_path_row(ip, ie, k, phc, mag, phase, &
     &           redfac, xlambda, realp)
      integer, intent(in) :: ip, ie
      real*8, intent(in) :: k, phc, mag, phase, redfac, xlambda, realp

      if (.not.allocated(res_pk)) return
      if (ip.lt.1 .or. ip.gt.size(res_pk,2)) return
      if (ie.lt.1 .or. ie.gt.size(res_pk,1)) return

      res_pk(ie,ip)      = k
      res_pphc(ie,ip)    = phc
      res_pmag(ie,ip)    = mag
      res_pphase(ie,ip)  = phase
      res_predfac(ie,ip) = redfac
      res_plambda(ie,ip) = xlambda
      res_prealp(ie,ip)  = realp

      return
      end subroutine feff_results_store_path_row

!     Called once feffdt's path loop has written every path.  ne and np are passed
!     rather than inferred, for the same reason feff_results_done_chi takes n: a
!     loop that exited early must not be able to set the flag.
      subroutine feff_results_done_paths(ne, np)
      integer, intent(in) :: ne, np
      res_pne = ne
      res_npaths_stored = np
      res_have_paths = .true.
      return
      end subroutine feff_results_done_paths

      end module feff_results
