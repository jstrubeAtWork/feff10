!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Information about last revision of $RCSfile: ff2x.f90,v $:
! $Revision: 1.4 $
! $Author: jorissen $
! $Date: 2012/05/15 21:29:59 $
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! feffjl Phase 1: the body of this stage now lives in subroutine feff_ff2x() so it
! can be called in-process by feff_run_exafs (HEADERS/feff_exafs.f90).
! FF2X/ff2x_main.f90 is the thin shim for the standalone `ff2x` executable.
!
! Note: the stale HEADERS/feff.f90 called this as `ffmod6(iabs)`, i.e. with the
! absorber index as an argument, for the nabs>1 configurational-average loop.
! The standalone executable has always hardcoded iabs=1, so feff_ff2x keeps it
! internal -- matching current behaviour rather than the abandoned intent.
! Configurational averaging (ffsort/nabs>1) is out of scope for Phase 1.
!
      subroutine feff_ff2x

!     final calculations for various spectroscopies
!     (EXAFS, XANES, FPRIME, DANES, XES)
!     written by a.ankudinov 2000
!     modified by a.ankudinov 2001 for new I/O structure

!     INPUT: mod6.inp global.dat xsect.bin fms.bin list.dat and feff.bin
!     OUTPUT: xmu.dat (chi.dat for EXAFS)

	  use par
	  use eels_inp,only: elnes=>eels,ipmin,ipmax,ipstep
      use ff2x_inp
	  use global_inp
	  use nrixs_inp
	  use errorfile
      use dimsmod, only: init_dimensions
      implicit none
	  integer ios,iabs


      call par_begin
      if (worker) go to 400
      call OpenErrorfileAtLaunch('ff2x')
      call init_dimensions

      iabs = 1
!     open the log file, unit 11.  See subroutine wlog.
      open (unit=11, file='log6.dat', status='unknown', iostat=ios)
      call chopen (ios, 'log6.dat', 'feff')

!     read  input files
      call reff2x
      if (mchi .eq. 1)  then
         call wlog('Calculating XAS spectra ...')
                 ! JK - added abs(ispec) below, to keep XANES grids if
                 ! XANES is specified.
		 if (do_nrixs .eq. 1) then					!NRIXS
			if (abs(ispec).gt.0 .and. ispec.lt.3) then
!				using FMS+Paths method
				call ff2xmujas (ispec, ipr6, idwopt, critcw, s02, sig2g, tk, thetad, mbconv, &
                         vrcorr, vicorr, alphat, thetae, iabs, nabs, kfinmax, xivec, ldecmx,abs(ldecmx))
			elseif (ispec.eq.3 .or. ispec.eq.4) then 
!				using FMS+Paths method
				call ff2afsjas ( ipr6, idwopt, critcw, s02, sig2g, tk, thetad, mbconv, &
                         vrcorr, vicorr, alphat, thetae, iabs, nabs, kfinmax, xivec, ldecmx,abs(ldecmx))
			else
!				using MS Paths expansion
				call ff2chijas (ispec, ipr6, idwopt, critcw, s02, sig2g, tk, thetad, mbconv, &
                         vrcorr, vicorr, alphat, thetae, iabs, nabs, kfinmax, xivec, ldecmx,abs(ldecmx))
			endif
         else										!REGULAR FEFF
			if (abs(ispec).gt.0 .and. ispec.lt.3) then ! JJK - added abs still use XANES grid if XANES is specified.
!				using FMS+Paths method
            call ff2xmu (abs(ispec), ipr6, idwopt, critcw, s02, sig2g, tk, thetad, mbconv, absolu,  &
                         vrcorr, vicorr, alphat, thetae, iabs, nabs, elnes,ipmin,ipmax,ipstep,iGammaCH)    
			elseif (ispec.eq.3 .or. ispec.eq.4) then 
!				using FMS+Paths method
				call ff2afs ( ipr6, idwopt, critcw, s02, sig2g, tk, thetad, mbconv, absolu,  &
                         vrcorr, vicorr, alphat, thetae, iabs, nabs, elnes,ipmin,ipmax,ipstep)        
			else
!				using MS Paths expansion
				call ff2chi (ispec, ipr6, idwopt, critcw, s02, sig2g,  tk, thetad, mbconv, absolu,  &
                         vrcorr, vicorr, alphat, thetae, iabs, nabs, elnes,ipmin,ipmax,ipstep)      
			endif
		 endif
         call wlog('Done with module: XAS spectra (FF2X: DW + final sum over paths).'//char(13)//char(10))
      endif
      close (unit=11)

  400 call par_barrier
      call par_end
	  if(master)call WipeErrorfileAtFinish
!     sub-program exchange
      return

      end subroutine feff_ff2x
