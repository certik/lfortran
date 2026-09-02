! C1514: specifics that differ only by an OPTIONAL argument are not
! distinguishable (the optional argument does not count under rule (1)).
module c1514_bad_3_m
    implicit none
    interface g   ! {error C1514}
        module procedure g_a, g_b
    end interface
contains
    integer function g_a(x)
        integer, intent(in) :: x
        g_a = 1
    end function
    integer function g_b(x, y)
        integer, intent(in) :: x
        integer, intent(in), optional :: y
        g_b = 2
    end function
end module
program c1514_bad_3
    use c1514_bad_3_m
    implicit none
    print *, g(1)
end program
