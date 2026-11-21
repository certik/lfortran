! A generic procedure calls a dummy procedure whose interface is an instance
! of a generic abstract interface (DI extension E4) with an argument resolved
! through a trait object by a generic message with a trait parameter (E10):
! `ctor(c%resolve{T1}())`, the shape of create1 in the DI container, as a
! free generic procedure. T1 and U are inferred from the actual procedure or
! given explicitly; the result is returned as type(U) or as class(*).
! GFortran does not accept this LFortran extension.
module traits_trait_param_runtime_03_m
    implicit none
    private
    public :: IResolver, ILogger, Container, Client, Service, ctor1, &
        make_client, make_service, create1, create1_any

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function resolve
    end interface IResolver

    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    abstract interface
        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    type, implements(ILogger) :: Logger
        integer :: lv = 0
    contains
        procedure :: level => logger_level
    end type Logger

    type, sealed, implements(IResolver) :: Container
        integer :: lv = 7
    contains
        procedure :: resolve
    end type Container

    type :: Client
        integer :: n = 0
    end type Client

    type :: Service
        integer :: m = 0
    end type Service

contains

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(*), allocatable :: made
        made = Logger(self%lv)
        select type (obj => made)
        class is (P)
            res = obj
        class default
            error stop "No registration available for " // type_name{P}() // "!"
        end select
    end function resolve

    function make_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = 2 * logger%level()
    end function make_client

    function make_service(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Service) :: self
        self%m = logger%level() + 100
    end function make_service

    function create1{Trait :: T1, U}(ctor, c) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(IResolver), intent(in) :: c
        type(U) :: r
        r = ctor(c%resolve{T1}())
    end function create1

    function create1_any{Trait :: T1, U}(ctor, c) result(res)
        procedure(ctor1{T1,U}) :: ctor
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = ctor(c%resolve{T1}())
    end function create1_any

end module traits_trait_param_runtime_03_m

program traits_trait_param_runtime_03
    use traits_trait_param_runtime_03_m
    implicit none
    type(Container) :: cont
    class(IResolver), allocatable :: r
    type(Client) :: cl
    type(Service) :: sv
    class(*), allocatable :: obj

    cl = create1(make_client, cont)
    if (cl%n /= 14) error stop 1

    cont%lv = 9
    r = cont
    sv = create1(make_service, r)
    if (sv%m /= 109) error stop 2

    cl = create1{ILogger, Client}(make_client, r)
    if (cl%n /= 18) error stop 3

    obj = create1_any(make_client, r)
    select type (obj)
    type is (Client)
        if (obj%n /= 18) error stop 4
    class default
        error stop 5
    end select

    obj = create1_any(make_service, cont)
    select type (obj)
    type is (Service)
        if (obj%m /= 109) error stop 6
    class default
        error stop 7
    end select

    print '(a)', 'ok'
end program traits_trait_param_runtime_03
