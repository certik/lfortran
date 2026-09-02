! C1514: two specific procedures of a generic that differ only in the name of
! their dummy argument are not distinguishable.
module c1514_bad_1_m
    implicit none
    interface g   ! {error C1514}
        module procedure g_a, g_b
    end interface
contains
    integer function g_a(x)
        integer, intent(in) :: x
        g_a = 1
    end function
    integer function g_b(y)
        integer, intent(in) :: y
        g_b = 2
    end function
end module
program c1514_bad_1
    use c1514_bad_1_m
    implicit none
    print *, g(1)
end program
