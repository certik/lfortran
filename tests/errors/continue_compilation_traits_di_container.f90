! Registrations that the dependency injection container of Sect. 4 of the
! traits extension proposal (Traits-for-Fortran
! Extensions/traits-di-extension.md) rejects at compile time: a type that
! does not implement the trait it is registered with (Sects. 3.3 and 3.7,
! with the reason of each specific of `register`), a type whose initializer
! takes an argument that is not a trait object, so that no `register`
! matches (Sect. 5, "Dependencies must be traits"), and a registration
! without the explicit type argument `{P}`, which no argument determines.
module continue_compilation_traits_di_container_m
    implicit none
    private
    public :: ILogger, IPrinter, Printer, SingleLogger, FileLogger, Container

    abstract interface :: ILogger
        subroutine log(self)
            type(itself), pass, intent(in) :: self
        end subroutine log
    end interface

    abstract interface :: IPrinter
        subroutine printout()
        end subroutine printout
    end interface

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U)               :: res
        end function ctor1

        function ctor2{Trait :: T1, Trait :: T2, U}(a, b) result(res)
            class(T1), intent(in) :: a
            class(T2), intent(in) :: b
            type(U)               :: res
        end function ctor2
    end interface

    type, implements(IPrinter) :: Printer
    contains
        procedure, nopass :: printout
    end type Printer

    type, implements(ILogger) :: SingleLogger
        private
        class(IPrinter), allocatable :: printer
    contains
        initial   :: init_single
        procedure :: log => log_single
    end type SingleLogger

    ! A configuration value as the initializer's argument.
    type, implements(ILogger) :: FileLogger
        private
        integer :: unit
    contains
        initial   :: init_file
        procedure :: log => log_file
    end type FileLogger

    type :: Container
        private
        character(:), allocatable :: last
    contains
        generic   :: register => register0, register1, register2
        procedure :: register0, register1, register2
    end type Container

contains

    subroutine printout()
        print *, "printing  ..."
    end subroutine printout

    function init_single(printer) result(self)
        class(IPrinter), intent(in) :: printer
        type(SingleLogger)          :: self
        self%printer = printer
    end function init_single

    subroutine log_single(self)
        class(SingleLogger), intent(in) :: self
        call self%printer%printout()
    end subroutine log_single

    function init_file(unit) result(self)
        integer, intent(in) :: unit
        type(FileLogger)    :: self
        self%unit = unit
    end function init_file

    subroutine log_file(self)
        class(FileLogger), intent(in) :: self
        print *, self%unit
    end subroutine log_file

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor0{U})             :: ctor
        self%last = type_name{P}()
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor1{T1,U})          :: ctor
        self%last = type_name{P}()
    end subroutine register1

    subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor2{T1,T2,U})       :: ctor
        self%last = type_name{P}()
    end subroutine register2

end module continue_compilation_traits_di_container_m

program continue_compilation_traits_di_container
    use continue_compilation_traits_di_container_m
    implicit none
    type(Container) :: cont
    ! Valid: register1{ILogger, IPrinter, SingleLogger}.
    call cont%register{ILogger}(SingleLogger)
    ! Printer does not implement ILogger.
    call cont%register{ILogger}(Printer)
    ! FileLogger's initializer takes an integer, not a trait object.
    call cont%register{ILogger}(FileLogger)
    ! P is not determined by the argument.
    call cont%register(SingleLogger)
end program continue_compilation_traits_di_container
