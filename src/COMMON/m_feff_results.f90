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

      end module feff_results
