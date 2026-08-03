!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Information about last revision of $RCSfile: feffdt.f90,v $:
! $Revision: 1.4 $
! $Author: hebhop $
! $Date: 2010/02/23 23:52:06 $
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       subroutine feffdt(ntotal,iplst,nptot,ntext,text,ne,npot,         &
     &      ihole, iorder, l0, rnrmav, xmu, edge, potlbl,               &
     &      iz,phc,ck,xk,index,                                         &
     &      nleg,deg,nepts,reff,crit,ipot,rat,achi,phchi)
!
!     writes feffnnnn.dat files and files.dat 
!     for compatibility with the old feff
!
      use dimsmod, only: npx=>npx_ff2x, nheadx, nex, nphx=>nphu, legtot
	  use constants
!     feffjl Phase 4 step 3: capture the per-path data as it is written, for the
!     C ABI's feff_get_path_* getters.  Storage only -- no iso_c_binding here, so
!     the standalone executables still compile unchanged (see m_feff_results.f90).
      use feff_results, only: feff_results_alloc_paths,                  &
     &     feff_results_store_path_info, feff_results_store_path_leg,    &
     &     feff_results_store_path_row, feff_results_done_paths
      implicit double precision (a-h, o-z)

      include '../HEADERS/vers.h'
      parameter (eps4 = 1.0e-4)
      parameter (eps = 1.0e-16)

      !parameter (npx=1200) !now in dimsmod
      character*12 fname(npx)
      character*512 slog
      dimension iplst(npx)

!     Stuff from feff.bin, note that floating point numbers are
!     single precision
!c      character*78 string
      real rnrmav, xmu, edge
!c      dimension ltext(nheadx)
      character*80 text(nheadx)
      character*6  potlbl(0:nphx)
      dimension iz(0:nphx)
!     central atom phase shift at l0
      complex phc(nex)
      complex ck(nex)
      real xk(nex)
      dimension index(npx)
      dimension nleg(npx)
      real deg(npx), reff(npx), crit(npx)
      dimension ipot(legtot,npx)
      real rat(3,legtot,npx)
!c      real beta(legtot,npx)
!c      real eta(legtot,npx)
!c      real ri(legtot,npx)
      real achi(nex,npx), phchi(nex,npx)
       integer istrln
       complex*16 cchi, cfms
       external istrln

       call wlog (' feffdt, feff.bin to feff.dat conversion ' // vfeff)

!     read feff.bin
!     Use single precision for all fp numbers in feff.bin
      do 20  itext = 1, ntext
         ltxt = istrln(text(itext))
!        text(itext) does not have carriage control
         call wlog (' ' // text(itext)(1:ltxt))
   20 continue

      write(slog,60)  nptot
   60 format (i8, ' paths to process')
      call wlog (slog)

!     Size the per-path capture buffers before the write loop.  ntotal, not nptot:
!     the loop below runs over list.dat's paths (ilist = 1, ntotal) and writes one
!     feffNNNN.dat each, so ntotal is the number of paths that will be stored.
!     `ne` here is ff2chi's ne1, the genfmt energy grid -- not chi.dat's fine grid,
!     which is why the per-path getters carry their own length.
      call feff_results_alloc_paths(ne, ntotal, legtot)

!     make files.dat
  150 format (a)
  160 format (1x, a)
  170 format (1x, 71('-'))

!     Save filenames of feff.dat files
      open (unit=2, file='files.dat', status='unknown', iostat=ios)
      call chopen (ios, 'files.dat', 'genfmt')
!     Put phase header on top of files.dat
      do 200  itext = 1, ntext
         ltxt = istrln( text(itext))
         write(2,160)  text(itext)(1:ltxt)
  200 continue
      write(2,170)
      write(2,210)
  210 format ('    file        sig2   amp ratio    ',                   &
     &        'deg    nlegs  r effective')
!     do each path
      call wlog ('    path     filename')

      do 500  ilist = 1, ntotal
!        find index of path
         do 410  j = 1, nptot
            if (iplst(ilist) .eq. index(j))  then
               i = j
               goto 430
            endif
  410    continue
         write(slog,420)  ilist, iplst(ilist)
  420    format (' did not find path i, iplst(i) ', 2i10)
         call wlog(slog)
  430    continue
!        Path i is the path from feff.bin that corresponds to
!        the path ilist in list.dat.  The index of the path is
!        iplst(ilist) and index(i).

!        Prepare output file feffnnnn.dat
         write(fname(i),220)  index(i)
  220    format ('feff', i4.4, '.dat')
         write(slog,230)  i, fname(i)
  230    format (i8, 5x, a)
         call wlog(slog)
!        zero is debye-waller factor column
         write(2,240) fname(i), zero, crit(i), deg(i),                  &
     &                   nleg(i), reff(i)*bohr
  240    format(1x, a, f8.5, 2f10.3, i6, f9.4)

         ip = i
!     Write feff.dat's
         open (unit=3, file=fname(ip), status='unknown', iostat=ios)
         call chopen (ios, fname(ip), 'feffdt')
!        put header on feff.dat
         do 300  itext = 1, ntext
            ltxt = istrln(text(itext))
            write(3,160)  text(itext)(1:ltxt)
  300    continue
         write(3,310) ip, iorder
  310    format (' Path', i5, '      icalc ', i7)
         write(3,170)
         write(3,320)  nleg(ip), deg(ip), reff(ip)*bohr, rnrmav,        &
     &                 edge*hart
  320    format (1x, i3, f8.3, f9.4, f10.4, f11.5,                      &
     &           ' nleg, deg, reff, rnrmav(bohr), edge')
!        Capture this path's header scalars.  Stored at ilist, the position in
!        list.dat / write order, with index(ip) kept as the path's own id -- the
!        two differ, and a caller correlating with files.dat needs the id.  reff is
!        stored already scaled by bohr, matching the file's units rather than
!        feff.bin's.
         call feff_results_store_path_info(ilist, index(ip), nleg(ip),   &
     &        dble(deg(ip)), dble(reff(ip))*bohr, dble(crit(ip)))

!        Legs, stored under their own rat index rather than in the order the file
!        prints them -- feffNNNN.dat writes the absorbing atom (leg nleg) first and
!        then legs 1..nleg-1, which is a presentation choice; a caller wants
!        rat(:,ileg) to mean what it means everywhere else in FEFF.
         do 365 ileg = 1, nleg(ip)
            call feff_results_store_path_leg(ilist, ileg,                &
     &           dble(rat(1,ileg,ip))*bohr, dble(rat(2,ileg,ip))*bohr,   &
     &           dble(rat(3,ileg,ip))*bohr, ipot(ileg,ip))
  365    continue

         write(3,330)
  330    format ('        x         y         z   pot at#')
         write(3,340)  (rat(j,nleg(ip),ip)*bohr,j=1,3),                 &
     &                 ipot(nleg(ip),ip),                               &
     &                 iz(ipot(nleg(ip),ip)), potlbl(ipot(nleg(ip),ip))
  340    format (1x, 3f10.4, i3, i4, 1x, a6, '   absorbing atom')
         do 360  ileg = 1, nleg(ip)-1
            write(3,350)  (rat(j,ileg,ip)*bohr,j=1,3), ipot(ileg,ip),   &
     &                    iz(ipot(ileg,ip)), potlbl(ipot(ileg,ip))
  350       format (1x, 3f10.4, i3, i4, 1x, a6)
  360    continue

         write(3,370)
  370    format    ('    k   real[2*phc]   mag[feff]  phase[feff]',     &
     &              ' red factor   lambda     real[p]@#')

!        Make the feff.dat stuff and write it to feff.dat
!        Also write out for inspection to fort.66
!        note that dimag takes complex*16 argument, aimag takes
!        single precision complex argument.  Stuff from feff.bin
!        is single precision, cchi is complex*16
         do 450  ie = 1, ne
!           Consider chi in the standard XAFS form.  Use R = rtot/2.
            cchi = achi(ie,ip) * exp (coni*phchi(ie,ip))
            xlam = 1.0e10
            if (abs(aimag(ck(ie))) .gt. eps) xlam = 1/aimag(ck(ie))
            redfac = exp (-2 * aimag (phc(ie)))
            cdelt = 2*dble(phc(ie))
            cfms = cchi * xk(ie) * reff(ip)**2 *                        &
     &           exp(2*reff(ip)/xlam) / redfac
            if (abs(cchi) .lt. eps)  then
               phff = 0
            else
               phff = atan2 (dimag(cchi), dble(cchi))
            endif
!           remove 2 pi jumps in phases
            if (ie .gt. 1)  then
               call pijump (phff, phffo)
               call pijump (cdelt, cdelto)
            endif
            phffo = phff
            cdelto = cdelt

!           write 1 k, momentum wrt fermi level k=sqrt(p**2-kf**2)
!                 2 central atom phase shift (real part),
!                 3 magnitude of feff,
!                 4 phase of feff,
!                 5 absorbing atom reduction factor,
!                 6 mean free path = 1/(Im (p))
!                 7 real part of local momentum p

            write(3,400)                                                &
     &         xk(ie)/bohr,                                             &
     &         cdelt + l0*pi,                                           &
     &         abs(cfms) * bohr,                                        &
     &         phff - cdelt - l0*pi,                                    &
     &         redfac,                                                  &
     &         xlam * bohr,                                             &
     &         dble(ck(ie))/bohr
  400       format (1x, f6.3, 1x, 3(1pe11.4,1x),1pe10.3,1x,             &
     &                            2(1pe11.4,1x))

!           The same seven expressions the write statement above just formatted,
!           in the same order.  Written as a second statement rather than via
!           temporaries so the two cannot drift apart silently: if a column's
!           expression is ever changed, the diff shows both lines side by side.
!           Note phff/cdelt are used here BEFORE the phffo/cdelto assignment below
!           updates them for the next iteration -- same values the file gets.
            call feff_results_store_path_row(ilist, ie,                  &
     &         xk(ie)/bohr,                                              &
     &         cdelt + l0*pi,                                            &
     &         abs(cfms) * bohr,                                         &
     &         phff - cdelt - l0*pi,                                     &
     &         dble(redfac),                                             &
     &         xlam * bohr,                                              &
     &         dble(ck(ie))/bohr)

  450    continue

!        Done with feff.dat
         close (unit=3)
  500 continue
      close (unit=2)

!     Only now, once every path has been written: the flag says "complete", so a
!     run that died partway through the loop above must not set it.
      call feff_results_done_paths(ne, ntotal)

      return
      end
