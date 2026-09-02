! C801 (R801): the DIMENSION attr-spec appears twice in one
! type-declaration-stmt, even though the array-specs agree.
program c801_bad_2
    implicit none
    integer, dimension(3), dimension(3) :: a   ! {error C801}
    a = 1
end program
