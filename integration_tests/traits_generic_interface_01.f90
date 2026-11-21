! Generic abstract interfaces and inference through dummy procedures (DI
! extension E4). The abstract interfaces ctor0{U}, ctor1{Trait :: T1, U}
! and ctor2{Trait :: T1, Trait :: T2, U} describe initializers taking
! zero, one or two trait objects; map1{T, U} a function of intrinsic types.
! A generic procedure with a dummy `procedure(ctor1{T1,U}) :: ctor` infers
! T1 and U from the characteristics of the actual procedure, alone or
! after leading explicit type arguments (E5), also when the actual is
! itself such a dummy of an enclosing generic, which forwards it. A local
! procedure pointer has an instantiated interface, with concrete type
! arguments or the enclosing generic's parameters. The actual procedure can
! also be an external procedure with an explicit interface.
! GFortran does not accept this LFortran extension.
module traits_generic_interface_01_m
    implicit none
    private
    public :: ILogger, IPrinter, IClient, Logger, Printer, Client, &
        ctor0, ctor1, ctor2, map1, visit1, make_logger, make_client, &
        make_client2, half, twice, bump, build0, build1, build2, &
        register1, forward1, through_pointer, apply_map, apply_visit, &
        type_names1

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

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    type, implements(ILogger) :: Logger
        integer :: lv = 5
    contains
        procedure :: level => logger_level
    end type Logger

    type, implements(IPrinter) :: Printer
        integer :: w = 3
    contains
        procedure :: width => printer_width
    end type Printer

    type, implements(IClient) :: Client
        integer :: n = 0
    contains
        procedure :: serve => client_serve
    end type Client

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1

        function ctor2{Trait :: T1, Trait :: T2, U}(a, b) result(res)
            class(T1), intent(in) :: a
            class(T2), intent(in) :: b
            type(U) :: res
        end function ctor2

        function map1{T, U}(x) result(y)
            type(T), intent(in) :: x
            type(U) :: y
        end function map1

        subroutine visit1{T}(x)
            type(T), intent(inout) :: x
        end subroutine visit1
    end interface

contains

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    integer function printer_width(self)
        class(Printer), intent(in) :: self
        printer_width = self%w
    end function printer_width

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%n
    end function client_serve

    ! Initializer-like module functions.
    function make_logger() result(self)
        type(Logger) :: self
        self%lv = 9
    end function make_logger

    function make_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = logger%level()
    end function make_client

    function make_client2(logger, printer) result(self)
        class(ILogger), intent(in) :: logger
        class(IPrinter), intent(in) :: printer
        type(Client) :: self
        self%n = 10 * logger%level() + printer%width()
    end function make_client2

    function half(x) result(y)
        integer, intent(in) :: x
        real(8) :: y
        y = x / 2.0d0
    end function half

    function twice(x) result(y)
        real, intent(in) :: x
        integer :: y
        y = nint(2 * x)
    end function twice

    subroutine bump(x)
        integer, intent(inout) :: x
        x = x + 1
    end subroutine bump

    ! U inferred from the actual procedure alone.
    function build0{U}(ctor) result(r)
        procedure(ctor0{U}) :: ctor
        type(U) :: r
        r = ctor()
    end function build0

    ! T1 and U inferred from the actual procedure and the trait object.
    function build1{Trait :: T1, U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(U) :: r
        r = ctor(a)
    end function build1

    function build2{Trait :: T1, Trait :: T2, U}(ctor, a, b) result(r)
        procedure(ctor2{T1,T2,U}) :: ctor
        class(T1), intent(in) :: a
        class(T2), intent(in) :: b
        type(U) :: r
        r = ctor(a, b)
    end function build2

    ! P given, T1 and U inferred; type(U) converts to class(P).
    function register1{Trait :: P, Trait :: T1, P :: U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        class(P), allocatable :: r
        r = ctor(a)
    end function register1

    ! The dummy ctor, whose interface is ctor1{T1,U}, passed on: build1
    ! infers its own T1 and U from it.
    function forward1{Trait :: T1, U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(U) :: r
        r = build1(ctor, a)
    end function forward1

    ! A local procedure pointer whose interface mentions the parameters.
    function through_pointer{Trait :: T1, U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(U) :: r
        procedure(ctor1{T1,U}), pointer :: p
        p => ctor
        r = p(a)
    end function through_pointer

    ! T and U bound to intrinsic types and kinds.
    function apply_map{T, U}(f, x) result(r)
        procedure(map1{T,U}) :: f
        type(T), intent(in) :: x
        type(U) :: r
        r = f(x)
    end function apply_map

    subroutine apply_visit{T}(v, x)
        procedure(visit1{T}) :: v
        type(T), intent(inout) :: x
        call v(x)
        call v(x)
    end subroutine apply_visit

    ! Only the procedure binds T1 and U.
    function type_names1{Trait :: T1, U}(ctor) result(names)
        procedure(ctor1{T1,U}) :: ctor
        character(:), allocatable :: names
        names = type_name{T1}() // "->" // type_name{U}()
    end function type_names1

end module traits_generic_interface_01_m

program traits_generic_interface_01
    use traits_generic_interface_01_m
    implicit none
    class(ILogger), allocatable :: lg
    class(IPrinter), allocatable :: pr
    class(IClient), allocatable :: cl
    type(Client) :: c
    type(Logger) :: l
    procedure(ctor1{ILogger, Client}), pointer :: p => null()
    procedure(map1{integer, real(8)}), pointer :: q
    integer :: k
    interface
        function ext_make_client(logger) result(self)
            import :: ILogger, Client
            class(ILogger), intent(in) :: logger
            type(Client) :: self
        end function ext_make_client
    end interface

    lg = Logger(7)
    pr = Printer(4)

    l = build0(make_logger)
    if (l%lv /= 9) error stop 1

    c = build1(make_client, lg)
    if (c%n /= 7) error stop 2

    c = build2(make_client2, lg, pr)
    if (c%n /= 74) error stop 3

    cl = register1{IClient}(make_client, lg)
    if (cl%serve() /= 7) error stop 4

    c = forward1(make_client, lg)
    if (c%n /= 7) error stop 5

    c = through_pointer(make_client, lg)
    if (c%n /= 7) error stop 6

    p => make_client
    c = p(lg)
    if (c%n /= 7) error stop 7
    ! The pointer is itself an actual procedure with an instantiated interface.
    c = build1(p, lg)
    if (c%n /= 7) error stop 8

    if (abs(apply_map(half, 3) - 1.5d0) > 1d-12) error stop 9
    if (apply_map(twice, 2.25) /= 5) error stop 10
    q => half
    if (abs(q(5) - 2.5d0) > 1d-12) error stop 11

    k = 1
    call apply_visit(bump, k)
    if (k /= 3) error stop 12

    if (type_names1(make_client) /= "ILogger->Client") error stop 13

    ! All type arguments explicit, and by keyword.
    c = build1{ILogger, Client}(make_client, lg)
    if (c%n /= 7) error stop 14
    c = build1{U=Client, T1=ILogger}(make_client, lg)
    if (c%n /= 7) error stop 15

    ! An external procedure with an explicit interface.
    c = build1(ext_make_client, lg)
    if (c%n /= 107) error stop 16

    print '(a)', 'traits_generic_interface_01 ok'
end program traits_generic_interface_01

function ext_make_client(logger) result(self)
    use traits_generic_interface_01_m, only: ILogger, Client
    implicit none
    class(ILogger), intent(in) :: logger
    type(Client) :: self
    self%n = logger%level() + 100
end function ext_make_client
