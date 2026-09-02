! C726 (R721 R722 R723): `*` as the type-param-value in the type-spec of an
! ALLOCATE statement whose allocate-object is a local allocatable, not a
! character dummy argument with assumed length.
program c726_bad_3
    implicit none
    character(:), allocatable :: s
    allocate(character(*) :: s)   ! {error C726}
end program
