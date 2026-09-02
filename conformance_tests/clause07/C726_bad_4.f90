! C726 (R721 R722 R723): `*` as a type-param-value declaring the result of a
! module function; only an external function may do so.
module c726_bad_4_m
    implicit none
contains
    function f() result(r)
        character(*) :: r   ! {error C726}
        r = "abc"
    end function
end module
program c726_bad_4
    use c726_bad_4_m
    implicit none
    print *, f()
end program
