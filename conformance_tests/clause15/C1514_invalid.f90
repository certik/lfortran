! C1514 Within the scope of a generic name, each pair of procedures identified
! by that name shall both be subroutines or both be functions, and shall be
! distinguishable.
module c1514_same_tkr
    implicit none
    interface g   ! {error C1514 same-tkr}
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
module c1514_function_and_subroutine
    implicit none
    interface g   ! {error C1514 function-and-subroutine}
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
module c1514_optional_only
    implicit none
    interface g   ! {error C1514 optional-only}
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
module c1514_intent_only
    implicit none
    interface g   ! {error C1514 intent-only}
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
module c1514_generic_interface_block
    implicit none
    interface g   ! {error C1514 interface-block}
        subroutine g_a(x)
            integer, intent(in) :: x
        end subroutine
        subroutine g_b(x)
            integer, intent(in) :: x
        end subroutine
    end interface
end module
