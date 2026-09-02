! C801 (R801) The same attr-spec shall not appear more than once in a given
! type-declaration-stmt.  Valid: each attribute appears at most once.
program c801_valid
    implicit none
    integer, dimension(3), parameter :: a = [1, 2, 3]
    real, allocatable, dimension(:) :: b
    allocate(b(2))
    b = 1.0
    if (size(a) /= 3) error stop
    if (size(b) /= 2) error stop
end program
