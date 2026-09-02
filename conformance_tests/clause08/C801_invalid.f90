! C801 (R801) The same attr-spec shall not appear more than once in a given
! type-declaration-stmt.
subroutine c801_allocatable()
    implicit none
    real, allocatable, allocatable :: b(:)   ! {error C801 allocatable}
    allocate(b(2))
end subroutine
subroutine c801_dimension()
    implicit none
    integer, dimension(3), dimension(3) :: a   ! {error C801 dimension}
    a = 1
end subroutine
subroutine c801_intent(x)
    implicit none
    integer, intent(in), intent(in) :: x   ! {error C801 intent}
end subroutine
subroutine c801_parameter()
    implicit none
    integer, parameter, parameter :: n = 1   ! {error C801 parameter}
end subroutine
module c801_public
    implicit none
    integer, public, public :: m = 1   ! {error C801 access-spec}
end module
