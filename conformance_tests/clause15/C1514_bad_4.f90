! C1514: specifics that differ only in the intent of a dummy argument are
! not distinguishable (intent is not part of TKR).
module c1514_bad_4_m
    implicit none
    interface g   ! {error C1514}
        module procedure g_a, g_b
    end interface
contains
    subroutine g_a(x)
        integer, intent(in) :: x
    end subroutine
    subroutine g_b(x)
        integer, intent(inout) :: x
        x = x + 1
    end subroutine
end module
program c1514_bad_4
    use c1514_bad_4_m
    implicit none
    integer :: i = 1
    call g(i)
end program
