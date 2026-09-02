! C801 (R801): the ALLOCATABLE attr-spec appears twice in one
! type-declaration-stmt.
program c801_bad_1
    implicit none
    real, allocatable, allocatable :: b(:)   ! {error C801}
    allocate(b(2))
end program
