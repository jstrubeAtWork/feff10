!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Information about last revision of $RCSfile: m_lnlm.f90,v $:
! $Revision: 1.2 $
! $Author: hebhop $
! $Date: 2010/02/23 23:52:06 $
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
module lnlm
  !--------------------------------------------------------------------
  ! Module for legendre polynomial normalization constants
  !
  ! Variables:
  !     xnlm:
  !   sigsqr:
  !
  ! Subroutines:
  !   init_lnlm: Allocates memory for module variables
  !   kill_lnlm: Deallocates memory for module variables
  !--------------------------------------------------------------------

  implicit none

  real, allocatable :: xnlm(:,:) 
  real, allocatable :: sigsqr(:,:)

contains

  subroutine init_lnlm(lx,nclusx)
    ! Idempotent: safe to call more than once in a process (in-process driver,
    ! feff_run_exafs).  A repeat call reallocates, since lx/nclusx can differ
    ! between runs.
    implicit none
    integer, intent(in) :: lx, nclusx

    if (allocated(xnlm))   deallocate(xnlm)
    if (allocated(sigsqr)) deallocate(sigsqr)
    allocate(xnlm(0:lx,0:lx))
    allocate(sigsqr(nclusx,nclusx))
  end subroutine init_lnlm

  subroutine kill_lnlm
    implicit none

    if (allocated(xnlm))   deallocate(xnlm)
    if (allocated(sigsqr)) deallocate(sigsqr)
  end subroutine kill_lnlm

end module lnlm
