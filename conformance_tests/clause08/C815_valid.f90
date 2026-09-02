! C815 An entity shall not be explicitly given any attribute more than once
! in a scoping unit.  Valid: each attribute given exactly once, using both
! the attr-spec and the attribute-statement forms for different entities.
module c815_valid_m
    implicit none
    integer :: m = 1
    public :: m
    integer, private :: p = 2
contains
    integer function get_p()
        get_p = p
    end function
end module
program c815_valid
    use c815_valid_m
    implicit none
    integer :: a(3)
    integer :: b
    allocatable :: b_alloc(:)
    integer :: b_alloc
    dimension :: b(2)
    save :: a
    a = 1
    b = 2
    allocate(b_alloc(2))
    if (m /= 1 .or. get_p() /= 2) error stop
    if (size(a) /= 3 .or. size(b) /= 2 .or. size(b_alloc) /= 2) error stop
end program
