! Generic abstract interfaces and inference through dummy procedures (DI
! extension E4): a generic interface named without type arguments, a wrong
! number of type arguments, actual procedures whose characteristics do not
! match the interface (intent, rank, kind, function or subroutine, number of
! arguments), a parameter that the actual procedure does not determine,
! type(P) of a trait parameter in a generic interface, and a parameter of
! the enclosing generic whose constraints do not imply those of the
! interface's parameter.
module continue_compilation_traits_generic_interface_m
    implicit none
    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    abstract interface
        function map1{T, U}(x) result(y)
            type(T), intent(in) :: x
            type(U) :: y
        end function map1

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1

    end interface

contains

    function half(x) result(y)
        integer, intent(in) :: x
        real(8) :: y
        y = x / 2.0d0
    end function half

    function half_inout(x) result(y)
        integer, intent(inout) :: x
        real(8) :: y
        y = x / 2.0d0
    end function half_inout

    function half_rank1(x) result(y)
        integer, intent(in) :: x(:)
        real(8) :: y
        y = x(1) / 2.0d0
    end function half_rank1

    function half_single(x) result(y)
        integer, intent(in) :: x
        real :: y
        y = x / 2.0
    end function half_single

    function same(x) result(y)
        integer, intent(in) :: x
        integer :: y
        y = x
    end function same

    subroutine not_a_function(x)
        integer, intent(in) :: x
    end subroutine not_a_function

    function two_args(x, z) result(y)
        integer, intent(in) :: x, z
        real(8) :: y
        y = x + z
    end function two_args

    function apply{T, U}(f, x) result(r)
        procedure(map1{T,U}) :: f
        type(T), intent(in) :: x
        type(U) :: r
        r = f(x)
    end function apply

    subroutine only_t{T, U}(f)
        procedure(map1{T,T}) :: f
    end subroutine only_t

    subroutine run()
        real(8) :: r
        r = apply(half_inout, 3)
        r = apply(half_rank1, 3)
        r = apply{integer, real(8)}(half_single, 3)
        r = apply(not_a_function, 3)
        r = apply(two_args, 3)
        call only_t(same)
    end subroutine run
end module

! Errors in declarations.
module continue_compilation_traits_generic_interface_decls
    use continue_compilation_traits_generic_interface_m, only: map1, ILogger
    implicit none
    abstract interface
        function log_map{ILogger :: T}(x) result(y)
            type(T), intent(in) :: x
            type(T) :: y
        end function log_map

        function bad_trait{Trait :: P}(a) result(res)
            type(P), intent(in) :: a
            integer :: res
        end function bad_trait
    end interface
contains
    function unbraced{T, U}(f, x) result(r)
        procedure(map1) :: f
        type(T), intent(in) :: x
        type(U) :: r
        r = x
    end function unbraced

    function unconstrained{T}(f, x) result(r)
        procedure(log_map{T}) :: f
        type(T), intent(in) :: x
        type(T) :: r
        r = f(x)
    end function unconstrained

    function too_few{T, U}(f, x) result(r)
        procedure(map1{T}) :: f
        type(T), intent(in) :: x
        type(U) :: r
    end function too_few

end module
