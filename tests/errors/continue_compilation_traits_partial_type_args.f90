! Partially explicit type arguments (E5) and calls that mix forwarded and
! concrete type arguments: too many type arguments, a parameter that neither
! an explicit argument nor an actual argument determines, and constraints of
! a mixed call, checked where it is made or, for `P :: U` with P forwarded,
! where the enclosing generic is instantiated.
module continue_compilation_traits_partial_type_args_m
    implicit none
    abstract interface :: IShow
        integer function code(self)
            type(itself), intent(in), pass :: self
        end function code
    end interface IShow

    abstract interface :: INum
        integer | real
    end interface INum

    type :: Plain
        integer :: v = 1
    end type Plain

    type, sealed :: Box
        integer :: k = 1
    contains
        procedure :: combine
    end type Box

contains

    function pair{INum :: T, INum :: U}(x, y) result(r)
        type(T), intent(in) :: x
        type(U), intent(in) :: y
        type(T) :: r
        r = x
    end function pair

    function pick{INum :: T, INum :: U}(x) result(r)
        type(T), intent(in) :: x
        type(T) :: r
        r = x
    end function pick

    function combine{INum :: T, INum :: U}(self, x) result(r)
        type(Box), intent(in) :: self
        type(T), intent(in) :: x
        type(T) :: r
        r = x
    end function combine

    subroutine named{Trait :: P}(n)
        integer, intent(out) :: n
        n = 1
    end subroutine named

    function wrap{Trait :: P, P :: U}(x) result(r)
        type(U), intent(in) :: x
        class(P), allocatable :: r
        r = x
    end function wrap

    function mixed{INum :: T}(x) result(r)
        type(T), intent(in) :: x
        type(T) :: r
        ! Too many type arguments.
        r = pair{T, integer, real}(x, 2)
        ! U is not determined.
        r = pick{T}(x)
        ! logical is not a member of INum.
        r = pair{T, logical}(x, .true.)
    end function mixed

    ! A forwarded type whose constraints do not imply the concrete trait.
    function unconstrained{V}(x) result(r)
        type(V), intent(in) :: x
        class(IShow), allocatable :: r
        r = wrap{IShow}(x)
    end function unconstrained

    ! Plain does not implement the trait bound to P in make{IShow}.
    function make{Trait :: P}() result(r)
        class(P), allocatable :: r
        r = wrap{P}(Plain())
    end function make

end module continue_compilation_traits_partial_type_args_m

program continue_compilation_traits_partial_type_args
    use continue_compilation_traits_partial_type_args_m
    implicit none
    type(Box) :: b
    class(IShow), allocatable :: v
    integer :: n
    print *, pair{integer, real, real}(1, 2.5)
    print *, b%combine{integer, real, integer}(1)
    print *, pick{integer}(1)
    print *, b%combine(1)
    call named(n)
    v = make{IShow}()
end program continue_compilation_traits_partial_type_args
