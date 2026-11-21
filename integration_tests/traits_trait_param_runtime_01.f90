! Generic messages with trait parameters called through trait objects (DI
! extension E10). IResolver's resolve{Trait :: P} is implemented by the
! generic type-bound procedure of a sealed Container, which looks up a
! hand-written factory by type_name{P}(qualified=.true.), queries
! `class is (P)` on what it creates and returns a class(P) trait object.
! Calls through class(IResolver) reach one erased copy of it, which
! receives the descriptor of the trait argument; calls on type(Container)
! are static instances. A factory resolves its own dependency through the
! class(IResolver) it is given, two traits with different numbers of
! messages are resolved, a generic procedure {Trait :: T1} forwards T1, and
! type_name{P}() is read from the descriptor in the erased copy.
! GFortran does not accept this LFortran extension.
module traits_trait_param_runtime_01_m
    implicit none
    private
    public :: IResolver, ILogger, IClient, IUnused, Logger, Client, Container, &
        resolve_via, resolve_twice, code_through

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function resolve
        ! Whether a factory is registered for P whose objects conform to P.
        logical function registered{Trait :: P}(self)
            type(itself), intent(in), pass :: self
        end function registered
        ! A code for the name of P, checked by value in the erased copy.
        integer function name_code{Trait :: P}(self, offset)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: offset
        end function name_code
    end interface IResolver

    ! One message.
    abstract interface :: ILogger
        integer function log(self, n)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: n
        end function log
    end interface ILogger

    ! Three messages: its trait objects have a larger header.
    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
        integer function logged(self, n)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: n
        end function logged
    end interface IClient

    abstract interface :: IUnused
        subroutine unused(self)
            type(itself), intent(in), pass :: self
        end subroutine unused
    end interface IUnused

    ! A hand-written factory: what the generic factories of the DI
    ! container make, per concrete type.
    abstract interface :: IFactory
        function create(self, c) result(res)
            type(itself), intent(in), pass :: self
            class(IResolver), intent(in) :: c
            class(*), allocatable :: res
        end function create
    end interface IFactory

    type, implements(ILogger) :: Logger
        integer :: lvl = 10
    contains
        procedure :: log => logger_log
    end type Logger

    type, implements(IClient) :: Client
        integer :: id = 1
        class(ILogger), allocatable :: logger
    contains
        procedure :: serve => client_serve
        procedure :: level => client_level
        procedure :: logged => client_logged
    end type Client

    type, implements(IFactory) :: LoggerFactory
        integer :: lvl = 0
    contains
        procedure :: create => create_logger
    end type LoggerFactory

    ! Resolves the logger of the client it makes through the container.
    type, implements(IFactory) :: ClientFactory
        integer :: id = 0
    contains
        procedure :: create => create_client
    end type ClientFactory

    type, sealed, implements(IResolver) :: Container
        integer :: lvl = 20
        integer :: id = 5
    contains
        procedure :: retrieve
        procedure :: resolve
        procedure :: registered
        procedure :: name_code
    end type Container

contains

    integer function logger_log(self, n)
        class(Logger), intent(in) :: self
        integer, intent(in) :: n
        logger_log = self%lvl + n
    end function logger_log

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%id
    end function client_serve

    integer function client_level(self)
        class(Client), intent(in) :: self
        client_level = 2 * self%id
    end function client_level

    integer function client_logged(self, n)
        class(Client), intent(in) :: self
        integer, intent(in) :: n
        client_logged = self%logger%log(n)
    end function client_logged

    function create_logger(self, c) result(res)
        class(LoggerFactory), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = Logger(self%lvl)
    end function create_logger

    function create_client(self, c) result(res)
        class(ClientFactory), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        type(Client) :: made
        made%id = self%id
        made%logger = c%resolve{ILogger}()
        res = made
    end function create_client

    ! The factory registered for the trait of the qualified name `key`, or
    ! none.
    subroutine retrieve(self, key, fact)
        type(Container), intent(in) :: self
        character(*), intent(in) :: key
        class(IFactory), allocatable, intent(out) :: fact
        select case (key)
        case ("traits_trait_param_runtime_01_m::ILogger")
            fact = LoggerFactory(self%lvl)
        case ("traits_trait_param_runtime_01_m::IClient")
            fact = ClientFactory(self%id)
        end select
    end subroutine retrieve

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(IFactory), allocatable :: fact
        class(*), allocatable :: made
        call self%retrieve(type_name{P}(qualified=.true.), fact)
        if (.not. allocated(fact)) then
            error stop "No registration available for " // type_name{P}() // "!"
        end if
        made = fact%create(self)
        select type (obj => made)
        class is (P)
            res = obj
        class default
            error stop "No registration available for " // type_name{P}() // "!"
        end select
    end function resolve

    logical function registered{Trait :: P}(self) result(found)
        type(Container), intent(in) :: self
        class(IFactory), allocatable :: fact
        class(*), allocatable :: made
        found = .false.
        call self%retrieve(type_name{P}(qualified=.true.), fact)
        if (.not. allocated(fact)) return
        made = fact%create(self)
        select type (obj => made)
        class is (P)
            ! P passed on through a trait object again.
            found = code_through{P}(self) > 0
        end select
    end function registered

    integer function qualified_length{Trait :: Q}() result(n)
        n = len(type_name{Q}(qualified=.true.))
    end function qualified_length

    integer function code_through{Trait :: Q}(c) result(n)
        class(IResolver), intent(in) :: c
        n = c%name_code{Q}(0)
    end function code_through

    integer function name_code{Trait :: P}(self, offset) result(code)
        type(Container), intent(in) :: self
        integer, intent(in) :: offset
        code = -1
        select case (type_name{P}())
        case ("ILogger")
            code = 1
        case ("IClient")
            code = 2
        case ("IUnused")
            code = 3
        end select
        if (type_name{P}(qualified=.true.) /= &
                "traits_trait_param_runtime_01_m::" // type_name{P}()) code = -2
        ! P passed on to a generic procedure, which receives the descriptor.
        if (qualified_length{P}() /= 33 + len(type_name{P}())) code = -3
        code = code + offset + 0 * self%id
    end function name_code

    ! A generic procedure forwarding its trait parameter through a trait
    ! object: each instance passes its trait's descriptor.
    function resolve_via{Trait :: T1}(c) result(r)
        class(IResolver), intent(in) :: c
        class(T1), allocatable :: r
        r = c%resolve{T1}()
    end function resolve_via

    ! Two trait parameters, each forwarded.
    logical function resolve_twice{Trait :: T1, Trait :: T2}(c) result(ok)
        class(IResolver), intent(in) :: c
        class(T1), allocatable :: a
        ok = c%registered{T1}() .and. .not. c%registered{T2}()
        a = c%resolve{T1}()
        ok = ok .and. allocated(a) .and. c%name_code{T2}(0) == 3
    end function resolve_twice

end module traits_trait_param_runtime_01_m

program traits_trait_param_runtime_01
    use traits_trait_param_runtime_01_m
    implicit none
    type(Container) :: cont
    class(IResolver), allocatable :: r
    class(IClient), allocatable :: c
    class(ILogger), allocatable :: l
    class(IUnused), allocatable :: u

    cont = Container(lvl=30, id=7)
    r = cont

    ! Through the erased copy.
    l = r%resolve{ILogger}()
    if (l%log(4) /= 34) error stop 1
    c = r%resolve{IClient}()
    if (c%serve() /= 7) error stop 2
    if (c%level() /= 14) error stop 3
    if (c%logged(5) /= 35) error stop 4

    ! Static instances on the concrete type.
    l = cont%resolve{ILogger}()
    if (l%log(1) /= 31) error stop 5
    c = cont%resolve{IClient}()
    if (c%logged(2) /= 32) error stop 6

    ! The missing registration, through a logical result.
    if (r%registered{IUnused}()) error stop 7
    if (.not. r%registered{IClient}() .or. .not. r%registered{ILogger}()) error stop 8
    if (allocated(u)) error stop 16

    ! type_name{P}() read from the descriptor.
    if (r%name_code{ILogger}(10) /= 11) error stop 9
    if (r%name_code{IClient}(10) /= 12) error stop 10
    if (r%name_code{IUnused}(0) /= 3) error stop 11
    if (cont%name_code{IClient}(0) /= 2) error stop 12
    if (code_through{ILogger}(cont) /= 1) error stop 17

    ! Forwarded trait parameters.
    l = resolve_via{ILogger}(r)
    if (l%log(0) /= 30) error stop 13
    c = resolve_via{IClient}(r)
    if (c%level() /= 14 .or. c%logged(1) /= 31) error stop 14
    if (.not. resolve_twice{IClient, IUnused}(r)) error stop 15

    print '(a)', 'traits_trait_param_runtime_01 ok'
end program traits_trait_param_runtime_01
