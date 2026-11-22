! Overloaded generic messages in a trait (DI extension E6). The trait
! IContainer declares three generic messages `register`, distinguishable by
! the arity of the interface of their dummy procedure `ctor`, as the DI
! container of the extension. A type implements them with the specifics of
! its generic binding `register`, each matched to the one message it
! corresponds to; each specific stores the constructor in a factory, an
! instance of a generic type with the message's trait parameters. Calls on
! the type, and through a generic parameter that IContainer constrains,
! select the specific by the E6 resolution rules, which prefer a message
! for which a type name designates an initializer to one for which it
! designates the structure constructor (E3). Generic procedures forward
! their constrained parameter to the one that calls the messages, one of
! them never called.
! GFortran does not accept this LFortran extension.
module traits_generic_overload_02_m
    implicit none
    private
    public :: ctor0, ctor1, ctor2, IContainer, IClient, ILogger, Client, Logger, &
        Service, DoubleLogger, Container, make_client, make_logger, setup, nested, &
        uncalled

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

    abstract interface :: IContainer
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U})               :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1,U})            :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor2{T1,T2,U})         :: ctor
        end subroutine register
    end interface

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    type, implements(IClient) :: Client
        integer :: id = 0
    contains
        procedure :: serve => client_serve
    end type Client

    type, implements(ILogger) :: Logger
        integer :: lvl = 0
    contains
        procedure :: level => logger_level
    end type Logger

    ! An initializer of one argument, and a structure constructor of none.
    type, implements(IClient) :: Service
        integer :: id = 0
    contains
        initial :: init_service
        procedure :: serve => service_serve
    end type Service

    ! An initializer of two arguments.
    type, implements(ILogger) :: DoubleLogger
        integer :: lvl = 0
    contains
        initial :: init_double
        procedure :: level => double_level
    end type DoubleLogger

    ! The factories of the container.
    type :: Factory0{U}
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    end type Factory0

    type :: Factory1{Trait :: T1, U}
        procedure(ctor1{T1,U}), pointer, nopass :: ctor => null()
    end type Factory1

    type :: Factory2{Trait :: T1, Trait :: T2, U}
        procedure(ctor2{T1,T2,U}), pointer, nopass :: ctor => null()
    end type Factory2

    ! The container of Sect. 4.5 of the extension, recording each
    ! registration as `trait:argument trait`.
    type, sealed, implements(IContainer) :: Container
        character(:), allocatable :: keys
        integer :: n0 = 0, n1 = 0, n2 = 0
    contains
        generic   :: register => register0, register1, register2
        procedure :: register0, register1, register2
    end type Container

contains

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%id
    end function client_serve

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lvl
    end function logger_level

    function init_service(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Service) :: self
        self%id = logger%level()
    end function init_service

    integer function service_serve(self)
        class(Service), intent(in) :: self
        service_serve = self%id
    end function service_serve

    function init_double(client, other) result(self)
        class(IClient), intent(in) :: client
        class(ILogger), intent(in) :: other
        type(DoubleLogger) :: self
        self%lvl = client%serve() + other%level()
    end function init_double

    integer function double_level(self)
        class(DoubleLogger), intent(in) :: self
        double_level = self%lvl
    end function double_level

    function make_client() result(res)
        type(Client) :: res
        res%id = 7
    end function make_client

    function make_logger(a) result(res)
        class(IClient), intent(in) :: a
        type(Logger) :: res
        res%lvl = a%serve()
    end function make_logger

    subroutine add_key(self, key)
        type(Container), intent(inout) :: self
        character(*), intent(in) :: key
        if (allocated(self%keys)) then
            self%keys = self%keys // "," // key
        else
            self%keys = key
        end if
    end subroutine add_key

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        class(P), allocatable :: object
        type(Factory0{U}) :: factory
        factory = Factory0(ctor)
        if (.not. associated(factory%ctor)) error stop "register0: no factory"
        object = ctor()
        if (.not. allocated(object)) error stop "register0: no object"
        self%n0 = self%n0 + 1
        call add_key(self, type_name{P}())
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        type(Factory1{T1,U}) :: factory
        factory = Factory1(ctor)
        if (.not. associated(factory%ctor)) error stop "register1: no factory"
        self%n1 = self%n1 + 1
        call add_key(self, type_name{P}() // ":" // type_name{T1}())
    end subroutine register1

    subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor2{T1,T2,U}) :: ctor
        type(Factory2{T1,T2,U}) :: factory
        factory = Factory2(ctor)
        if (.not. associated(factory%ctor)) error stop "register2: no factory"
        self%n2 = self%n2 + 1
        call add_key(self, type_name{P}() // ":" // type_name{T1}() // "+" // &
            type_name{T2}())
    end subroutine register2

    ! Generic code that only knows that CT implements IContainer.
    subroutine setup{IContainer :: CT}(cont)
        type(CT), intent(inout) :: cont
        call cont%register{IClient}(make_client)
        call cont%register{ILogger}(make_logger)
        ! A type name designates its structure constructor (E3).
        call cont%register{IClient}(Client)
        ! A type name designates its initializer rather than its structure
        ! constructor.
        call cont%register{IClient}(Service)
        call cont%register{ILogger}(DoubleLogger)
    end subroutine setup

    ! Forwards its constrained parameter, and calls an overload itself.
    subroutine nested{IContainer :: CT}(cont)
        type(CT), intent(inout) :: cont
        call setup(cont)
        call cont%register{ILogger}(make_logger)
    end subroutine nested

    ! Never called: its forwarding is checked all the same.
    subroutine uncalled{IContainer :: CT}(cont)
        type(CT), intent(inout) :: cont
        call nested(cont)
    end subroutine uncalled

end module traits_generic_overload_02_m

program traits_generic_overload_02
    use traits_generic_overload_02_m
    implicit none
    type(Container) :: cont

    call cont%register{IClient}(make_client)
    call cont%register{ILogger}(make_logger)
    if (cont%n0 /= 1 .or. cont%n1 /= 1) error stop 1
    if (cont%keys /= "IClient,ILogger:IClient") error stop 2

    call setup(cont)
    if (cont%n0 /= 3 .or. cont%n1 /= 3 .or. cont%n2 /= 1) error stop 3
    if (cont%keys /= "IClient,ILogger:IClient,IClient,ILogger:IClient,IClient," // &
        "IClient:ILogger,ILogger:IClient+ILogger") error stop 4
    call cont%register{IClient}(Service)
    call cont%register{ILogger}(DoubleLogger)
    if (cont%n1 /= 4 .or. cont%n2 /= 2) error stop 5
    call nested(cont)
    if (cont%n0 /= 5 .or. cont%n1 /= 7 .or. cont%n2 /= 3) error stop 6
    print *, cont%keys
end program traits_generic_overload_02
