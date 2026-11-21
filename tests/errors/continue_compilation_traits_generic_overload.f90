! Overloading of generic procedures (DI extension E6): generic specifics
! that are not distinguishable, in a generic interface and in a generic
! binding; a reference that no specific accepts, with the reason of each
! candidate (the arity of a designated initializer, an unmet conformance
! constraint through the generic name, a non-generic specific given type
! arguments); and a generic specific of the wrong category.
module continue_compilation_traits_generic_overload_m
    implicit none
    private
    public :: ILogger, IPrinter, Printer, Logger, Container, same, overlap, &
        mixed, ctor0, ctor1

    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    abstract interface :: IPrinter
        integer function width(self)
            type(itself), intent(in), pass :: self
        end function width
    end interface IPrinter

    abstract interface :: INumeric
        integer | real(4) | real(8)
    end interface INumeric

    type, implements(IPrinter) :: Printer
    contains
        procedure :: width => printer_width
    end type Printer

    type, implements(ILogger) :: Logger
        integer :: lv = 0
    contains
        initial :: init_logger
        procedure :: level => logger_level
    end type Logger

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1

        function other0{U}() result(res)
            type(U) :: res
        end function other0
    end interface

    type :: Container
        integer :: n = 0
    contains
        generic :: register => register0, register1
        procedure :: register0, register1
        ! Both take a dummy procedure without arguments.
        generic :: add => add0, add0b
        procedure :: add0, add0b
    end type Container

    ! An unconstrained parameter overlaps a type-set one.
    interface same
        module procedure same_any, same_numeric
    end interface same

    ! A type-set parameter overlaps a concrete member in the same position.
    interface overlap
        module procedure overlap_real, overlap_numeric
    end interface overlap

    ! A non-generic specific may overlap a generic one.
    interface mixed
        module procedure mixed_generic, mixed_real
    end interface mixed

contains

    integer function printer_width(self)
        class(Printer), intent(in) :: self
        printer_width = 80
    end function printer_width

    function init_logger(p) result(self)
        class(IPrinter), intent(in) :: p
        type(Logger) :: self
        self%lv = p%width()
    end function init_logger

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = 0
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        self%n = 1
    end subroutine register1

    subroutine add0{U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = 0
    end subroutine add0

    subroutine add0b{U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(other0{U}) :: ctor
        self%n = 2
    end subroutine add0b

    integer function same_any{U}(x) result(r)
        type(U), intent(in) :: x
        r = 1
    end function same_any

    integer function same_numeric{INumeric :: T}(x) result(r)
        type(T), intent(in) :: x
        r = 2
    end function same_numeric

    integer function overlap_real{T}(x, y) result(r)
        type(T), intent(in) :: x
        real(8), intent(in) :: y
        r = 1
    end function overlap_real

    integer function overlap_numeric{INumeric :: T, U}(x, y) result(r)
        type(U), intent(in) :: x
        type(T), intent(in) :: y
        r = 2
    end function overlap_numeric

    integer function mixed_generic{INumeric :: T}(x) result(r)
        type(T), intent(in) :: x
        r = 1
    end function mixed_generic

    integer function mixed_real(x) result(r)
        real(8), intent(in) :: x
        r = 2
    end function mixed_real

end module continue_compilation_traits_generic_overload_m

program continue_compilation_traits_generic_overload
    use continue_compilation_traits_generic_overload_m, only: ILogger, IPrinter, &
        Printer, Logger, Container, mixed
    implicit none
    type(Container) :: cont
    integer :: i
    ! No specific accepts Printer for ILogger: register0 by the constraint,
    ! register1 by the arity of Printer's constructor.
    call cont%register{ILogger}(Printer)
    ! Logger() fits register0 and Logger's initializer register1, but Logger
    ! does not implement IPrinter.
    call cont%register{IPrinter}(Logger)
    ! The non-generic specific does not take type arguments, and the generic
    ! one does not admit character.
    i = mixed{character(len=2)}("ab")
    ! A function reference to a generic binding of subroutines.
    i = cont%register{IPrinter}(Printer)
end program continue_compilation_traits_generic_overload
