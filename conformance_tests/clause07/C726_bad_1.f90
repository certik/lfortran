! C726 (R721 R722 R723): `*` as a type-param-value used to declare a local
! variable, which is none of the permitted contexts.
program c726_bad_1
    implicit none
    character(*) :: s   ! {error C726}
    s = "abc"
end program
