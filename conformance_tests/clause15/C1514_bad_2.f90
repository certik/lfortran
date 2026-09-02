! C1514: a generic shall not identify both a subroutine and a function.
module c1514_bad_2_m
    implicit none
    interface g   ! {error C1514}
        module procedure g_f, g_s
    end interface
contains
    integer function g_f(x)
        integer, intent(in) :: x
        g_f = 1
    end function
    subroutine g_s(x)
        real, intent(in) :: x
    end subroutine
end module
program c1514_bad_2
    use c1514_bad_2_m
    implicit none
    print *, g(1)
end program
