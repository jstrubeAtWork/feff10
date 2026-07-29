!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Information about last revision of $RCSfile: genfmt.f90,v $:
! $Revision: 1.11 $
! $Author: jorissen $
! $Date: 2012/05/15 21:29:59 $
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! feffjl Phase 1: the body of this stage now lives in subroutine feff_genfmt() so
! it can be called in-process by feff_run_exafs (HEADERS/feff_exafs.f90) -- which
! is what the original "sub-program exchange / subroutine ffmod5" comments
! intended.  GENFMT/genfmt_main.f90 is the shim for the standalone executable.
!
      subroutine feff_genfmt

!     scattering F-matrix multiplication for each MS path
!     written by a.ankudinov 2000, using subroutines
!     which were written earlier by j.rehr and others
!     modified by a.ankudinov 2001 for new I/O structure

!     INPUT: phase.bin, paths.dat, mod5.inp and global.dat
!     OUTPUT: feff.bin and list.dat files
      use dimsmod, only: init_dimensions, nspx=>nspu
	  use par
	  use genfmt_inp, only: mfeff
	  use nrixs_inp, only: do_nrixs
	  use global_inp, only: ispin
      !use eels_inp
	  use errorfile
	  implicit none
      integer ios
	  
      call par_begin
      if (worker) go to 400
      call OpenErrorfileAtLaunch('genfmt')
      ! Initialize dimensions - JK 08/09
      call init_dimensions

!     open the log file, unit 11.
      open (unit=11, file='log5.dat', status='unknown', iostat=ios)
      call chopen (ios, 'log5.dat', 'feff')

!     read  mod5.inp 
      call regenf    
      if (nspx.gt.1) ispin = abs(ispin)

      if (mfeff .eq. 1)  then
         call wlog('Calculating EXAFS parameters ...')
         if (do_nrixs .ne. 1) then  !regular FEFF
			call genfmt 
         else  ! NRIXS calculation
			call genfmtjas
	     endif
         call wlog('Done with module: EXAFS parameters (GENFMT).'//char(13)//char(10))
      endif
      close (unit=11)

 400  call par_barrier
      call par_end
      if(master)call WipeErrorfileAtFinish
!     sub-program exchange
      return

      end subroutine feff_genfmt
