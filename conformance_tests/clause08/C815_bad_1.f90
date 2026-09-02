! C815: an entity shall not be explicitly given any attribute more than once
! in a scoping unit.  (Distinct from C801: here the attribute is repeated
! across two statements, not within one type-declaration-stmt.)
program c815_bad_1
    implicit none
    integer, allocatable :: b(:)
    allocatable :: b   ! {error C815}
    allocate(b(2))
end program
