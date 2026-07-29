!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! feffjl Phase 1: clear the ATOM blank COMMON block between runs.
!
! cg/cp (radial orbital components) and bg/bp (their origin expansion
! coefficients) are filled by wfirdf for orbitals j = 1..norb only, but scfdat
! copies out the full j = 1..41 range into dgc/dpc/adgc/adpc.  Columns above norb
! therefore carry whatever was last left in COMMON.
!
! In a separate `atomic` process those columns are the zeros the loader supplies,
! so apot.bin gets zeros there.  In-process, run 2 inherits run 1's values: going
! GeCl_4 (Ge, 12 orbitals) -> Cu (11 orbitals) left Ge's 12th-orbital wavefunction
! in Cu's apot.bin.  Downstream stages index by norb and ignore those columns, so
! xmu.dat/chi.dat were unaffected -- but apot.bin differed from the stock output,
! which is exactly what the Phase-1 bit-for-bit gate exists to catch.
!
! Zeroing (rather than making the scfdat copy loop stop at norb) is the
! conservative fix: it reproduces the fresh-process starting state exactly and
! leaves every array bound alone.
!
! Call this once per run, from AtomicPotentials, BEFORE the first scfdat call --
! not per scfdat call.  Within one run scfdat is invoked once per unique
! potential and the accumulation across those calls is stock behaviour.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      subroutine reset_atom_common

      implicit double precision (a-h,o-z)
!     Declared exactly as in ATOM/scfdat.f90 and ATOM/wfirdf.f90.
      common cg(251,41), cp(251,41), bg(10,41), bp(10,41),              &
     &         fl(41), fix(41), ibgp
      common/ratom1/ xnel(41), en(41), scc(41), scw(41), sce(41),        &
     &         nq(41), kap(41), nmax(41)

      cg = 0.0d0
      cp = 0.0d0
      bg = 0.0d0
      bp = 0.0d0
      fl = 0.0d0
      fix = 0.0d0

!     nmax bounds the scfdat copy loops; a stale value would copy stale cg/cp
!     rows.  The rest of /ratom1/ is rewritten by inmuat on every scfdat call,
!     but is cleared here too so the whole block starts as a fresh process would.
      xnel = 0.0d0
      en = 0.0d0
      scc = 0.0d0
      scw = 0.0d0
      sce = 0.0d0
      nq = 0
      kap = 0
      nmax = 0

      return
      end subroutine reset_atom_common
