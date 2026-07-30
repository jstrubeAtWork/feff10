!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Information about last revision of $RCSfile: m_struct.f90,v $:
! $Revision: 1.12 $
! $Author: jorissen $
! $Date: 2012/01/31 22:47:21 $
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!*****************************************************************************
!       DEFINE THE UNIT CELL
!*****************************************************************************
      module struct

!    The space group
      integer sgroup  ! goes from 1 to 230
!    The H-M name of the space group
      character*8 sgroup_hm	  
!    The Bravais lattice
      character*3 latticename ! can be P,F,H,R,B,CXZ,CYZ
!    Similar to the above; here we only want to know whether we're in the "primitive" lattice or a "conventional" lattice	  
      character*1 lattice  ! allowed values :  P,F,I,B,C
!    The lattice constants
      real*8 alat(3),alfalat(3)
!    The lattice vectors
      real*8 a1(3),a2(3),a3(3)
!    The reciprocal lattice vectors
      real*8 b1(3),b2(3),b3(3)
!    Number of atoms
      integer nats
!    Number of potentials
      integer nph
!    Number of atoms per potential type
      integer,allocatable :: natom(:)
!    Index of representative atom for a potential type in the list of the atom positions of the unit cell
      integer,allocatable :: firstpos(:)	  
!    Positions of all atoms
      real*8, allocatable :: ppos(:,:)
!    Potential type of each position
      integer, allocatable :: ppot(:)
!    Position containing the absorber
      integer absorber
!    Angular expansion limit of potential
      integer,allocatable :: lpot(:)
!    Atom type for each potential
      character*2,allocatable :: label(:)
!    Atomic number z for each potential
      integer,allocatable :: izatom(:)	  
!    Number of spin states
      integer nsp
!    Volume of the unit cell :
      real*8 celvol
!    Volume of the reciprocal unit cell
      real*8 volbz
!    Symmetry operations of the crystal
      real*8 cryst_gr(3,4,48,2)
!     cryst_gr(:,:,:,2) : in lattice coordinates
!     cryst_gr(:,:,:,1) : in carthesian coordinates
!    Number of symmetry operations of the crystal
      integer nsym
!    The Bravais matrix, in units 2 pi / a_i
      real*8 bramat(3,3)
!    Real space basis matrix
      real*8 rbas(3,3)
!    Reciprocal space basis matrix
      real*8 gbas(3,3)
!    Is the real space basis orthogonal or not
      logical ortho
!    Is a rhombohedral spacegroup defined in hexagonal basis?
      logical R_spacegroup_is_hexagonal

        CONTAINS

        subroutine init_struct(n)
        implicit none
        integer n

        ! JK - Check here if allocated. Keep going if they are.
!       feffjl Phase 3: resize when n has changed since the last call, rather than
!       skipping the allocation whenever the arrays already exist.  The plain
!       `.not.allocated` guard made a second call in the same process silently
!       reuse the FIRST call's extents, so a repeated run with more atoms wrote
!       past the end of ppos/ppot/... .  Harmless for one run per process, which is
!       all the standalone executables ever did; not harmless once feff_run_exafs
!       is called repeatedly through the C ABI.
!
!       Testing the EXTENT is what makes this work where the two earlier attempts
!       recorded in the comments at COMMON/m_inpmodules.f90:490-496 and
!       RDINP/importcif.f90:577 did not: `allocated(ppos)` alone cannot distinguish
!       "already the right size" from "already the wrong size", and `size(ppot)`
!       differs between compilers for a zero-length array (0 on ifort, 1 on
!       gfortran) so it cannot stand in for an allocation test either.  Same shape
!       as atoms_allocate / potential_allocate in COMMON/m_inpmodules.f90, which
!       fixed this same bug class for the nphx-shaped arrays in Phase 1a.
!
!       Note the two different lower bounds: ppos/ppot/natom/firstpos are 1:n,
!       while lpot/label/izatom are 0:n.  Each test uses its own array's extent.
		if(allocated(ppos)) then
		   if(size(ppos,2).ne.n) deallocate(ppos)
		endif
		if(allocated(ppot)) then
		   if(size(ppot).ne.n) deallocate(ppot)
		endif
		if(allocated(lpot)) then
		   if(size(lpot).ne.n+1) deallocate(lpot)
		endif
		if(allocated(natom)) then
		   if(size(natom).ne.n) deallocate(natom)
		endif
		if(allocated(label)) then
		   if(size(label).ne.n+1) deallocate(label)
		endif
		if(allocated(izatom)) then
		   if(size(izatom).ne.n+1) deallocate(izatom)
		endif
		if(allocated(firstpos)) then
		   if(size(firstpos).ne.n) deallocate(firstpos)
		endif
		if(.not.allocated(ppos)) allocate(ppos(3,n))
		if(.not.allocated(ppot)) allocate(ppot(n))
		if(.not.allocated(lpot)) allocate(lpot(0:n))
		if(.not.allocated(natom)) allocate(natom(n))
		if(.not.allocated(label)) allocate(label(0:n))
		if(.not.allocated(izatom)) allocate(izatom(0:n))
		if(.not.allocated(firstpos)) allocate(firstpos(n))

        ppos=dble(0)
        natom=0
        ppot=-1
        lpot=-1
		label(:)='     '
        if(absorber.lt.1.or.absorber.gt.n) absorber=1
! Modified by FDV
! Looks prettier and helps it compile in Solaris Studio
        if( (latticename.ne.'P  ' .and. latticename.ne.'F  ' .and. &
             latticename.ne.'I  ' .and. latticename.ne.'CXZ' .and. &
             latticename.ne.'CYZ' .and. latticename.ne.'H  ' .and. &
             latticename.ne.'R'   .and. latticename.ne.'B  ' .and. &
             latticename.ne.'CXY')  .or.  &
            (lattice .ne. 'P' .and. lattice .ne. 'F' .and. &
             lattice .ne. 'I' .and. lattice .ne. 'C' .and. &
             lattice .ne. 'H' .and. lattice .ne. 'R' .and. &
             lattice.ne.'B')  ) then
		   call wlog('Setting unknown lattice type '//latticename//' '//lattice//'  to P.')
		   lattice='P'
		   latticename='P  '
		endif
        if(sgroup.lt.1.or.sgroup.gt.230) sgroup=1
        ortho=.false.
        gbas=dble(0)
        rbas=dble(0)
        bramat=dble(0)
        cryst_gr=dble(0)
        nsym=0
        R_spacegroup_is_hexagonal=.true.

        end subroutine init_struct

        end module struct
