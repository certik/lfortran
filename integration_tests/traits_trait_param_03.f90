! A generic message with trait parameters (E1) and a conformance constraint
! (E2) in a generic constraint. The message's dummy procedure has a generic
! interface (E4) whose dummy is a trait object of a trait parameter. The
! implementation names its parameters differently. A generic procedure that
! the trait constrains calls the message with an explicit trait argument,
! the other type arguments inferred from the procedure, also from a type
! name designating a structure constructor (E3); each instance calls the
! implementing type's generic procedure. The implementation instantiates a
! generic type with its trait parameter, also in the instances made for the
! calls through the constraint. Generic procedures forward their constrained
! parameter to the one that calls the messages, one of them never called.
! GFortran does not accept this LFortran extension.
module traits_trait_param_03_m
    implicit none
    private
    public :: ctor0, ctor1, IRegistry, IClient, ILogger, Client, Logger, &
        Registry, make_client, make_logger, setup, nested, uncalled

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0
        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U)               :: res
        end function ctor1
    end interface

    abstract interface :: IRegistry
        subroutine add{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1,U})            :: ctor
        end subroutine add
        subroutine add_plain{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U})               :: ctor
        end subroutine add_plain
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
        integer :: id = 4
    contains
        procedure :: serve => client_serve
    end type Client

    type, implements(ILogger) :: Logger
        integer :: lvl = 0
    contains
        procedure :: level => logger_level
    end type Logger

    type, sealed, implements(IRegistry) :: Registry
        character(:), allocatable :: keys
        integer :: total = 0
    contains
        procedure :: add, add_plain
    end type Registry

    ! A factory of the dependency injection container of the extension.
    type :: Factory1{Trait :: T1, U}
        procedure(ctor1{T1,U}), pointer, nopass :: ctor => null()
    end type Factory1

contains

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%id
    end function client_serve

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lvl
    end function logger_level

    function make_client() result(res)
        type(Client) :: res
        res%id = 7
    end function make_client

    function make_logger(a) result(res)
        class(IClient), intent(in) :: a
        type(Logger) :: res
        res%lvl = 10 * a%serve()
    end function make_logger

    subroutine add_key(self, key)
        type(Registry), intent(inout) :: self
        character(*), intent(in) :: key
        if (allocated(self%keys)) then
            self%keys = self%keys // "," // key
        else
            self%keys = key
        end if
    end subroutine add_key

    ! The parameters have other names than the message's.
    subroutine add{Trait :: Q, Trait :: S, Q :: V}(self, ctor)
        type(Registry), intent(inout) :: self
        procedure(ctor1{S,V}) :: ctor
        type(Factory1{S,V}) :: factory
        factory = Factory1(ctor)
        if (.not. associated(factory%ctor)) error stop "add: no factory"
        self%total = self%total + 1
        call add_key(self, type_name{Q}() // ":" // type_name{S}())
    end subroutine add

    subroutine add_plain{Trait :: Q, Q :: V}(self, ctor)
        type(Registry), intent(inout) :: self
        procedure(ctor0{V}) :: ctor
        type(V) :: object
        class(Q), allocatable :: view
        object = ctor()
        view = object
        if (.not. allocated(view)) error stop "add_plain: no view"
        call add_key(self, type_name{Q}())
    end subroutine add_plain

    subroutine setup{IRegistry :: R}(reg)
        type(R), intent(inout) :: reg
        call reg%add{ILogger}(make_logger)
        call reg%add_plain{IClient}(make_client)
        call reg%add_plain{IClient}(Client)
    end subroutine setup

    ! Forwards its constrained parameter to `setup`.
    subroutine nested{IRegistry :: R}(reg)
        type(R), intent(inout) :: reg
        call setup(reg)
    end subroutine nested

    ! Never called: its forwarding is checked all the same.
    subroutine uncalled{IRegistry :: R}(reg)
        type(R), intent(inout) :: reg
        call nested(reg)
    end subroutine uncalled

end module traits_trait_param_03_m

program traits_trait_param_03
    use traits_trait_param_03_m
    implicit none
    type(Registry) :: reg

    call reg%add{ILogger}(make_logger)
    if (reg%keys /= "ILogger:IClient") error stop 1
    call setup(reg)
    if (reg%keys /= "ILogger:IClient,ILogger:IClient,IClient,IClient") error stop 2
    if (reg%total /= 2) error stop 3
    call nested(reg)
    if (reg%keys /= "ILogger:IClient,ILogger:IClient,IClient,IClient," // &
        "ILogger:IClient,IClient,IClient") error stop 4
    if (reg%total /= 3) error stop 5
    print *, reg%keys
end program traits_trait_param_03
