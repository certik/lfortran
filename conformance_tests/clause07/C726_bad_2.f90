! C726 (R721 R722 R723): `*` as a type-param-value used for a derived-type
! component; components are not among the permitted contexts.
program c726_bad_2
    implicit none
    type :: t
        character(*) :: s   ! {error C726}
    end type
    type(t) :: v
    v%s = "abc"
end program
