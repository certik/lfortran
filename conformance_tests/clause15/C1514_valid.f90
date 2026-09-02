! C1514: within the scope of a generic name, each pair of specific procedures
! shall be distinguishable.  Valid: distinguishable by type, by kind, by rank,
! and by the presence of a nonoptional argument the other lacks (rule (4)).
module c1514_valid_m
    implicit none
    interface g
        module procedure g_int, g_real, g_int8, g_int_rank1, g_two_args
    end interface
contains
    integer function g_int(x)
        integer, intent(in) :: x
        g_int = 1
    end function
    integer function g_real(x)
        real, intent(in) :: x
        g_real = 2
    end function
    integer function g_int8(x)
        integer(8), intent(in) :: x
        g_int8 = 3
    end function
    integer function g_int_rank1(x)
        integer, intent(in) :: x(:)
        g_int_rank1 = 4
    end function
    integer function g_two_args(x, y)
        integer, intent(in) :: x
        character(*), intent(in) :: y
        g_two_args = 5
    end function
end module
program c1514_valid
    use c1514_valid_m
    implicit none
    if (g(1) /= 1) error stop
    if (g(1.0) /= 2) error stop
    if (g(1_8) /= 3) error stop
    if (g([1, 2]) /= 4) error stop
    if (g(1, "a") /= 5) error stop
end program
