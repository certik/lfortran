! Generic initializers (DI extension E8) and their overloading (E9). An
! initializer may have type parameters of its own, independent of the type,
! which every reference infers, also through dummy procedures (E4) and type
! names (E3). A reference `T(args)` tries the non-generic initializers first,
! then the generic ones, then the structure constructor. The `Factory` of
! Sect. 4.4 of the extension selects init0, init1 or init2 by the arity of
! the interface of `ctor`, also when `ctor` is a dummy procedure of a generic
! whose interface mentions that generic's parameters (Sect. 4.5).
! GFortran does not accept this LFortran extension.

module traits_generic_init_01_app
    implicit none
    private
    public :: ILogger, IPrinter, IWriter, IClient, Printer, Writer, Client, &
        DoubleLogger, ctor0, ctor1, ctor2, make_printer, make_client, &
        make_double_logger, INumeric, whole

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

    abstract interface :: IWriter
        integer function lines(self)
            type(itself), intent(in), pass :: self
        end function lines
    end interface IWriter

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    abstract interface :: INumeric
        integer | real(4) | real(8)
    end interface INumeric

    ! A non-generic initializer without arguments, which a type name
    ! designates, and a generic one with a data argument.
    type, implements(IPrinter) :: Printer
        private
        integer :: w = 80
    contains
        initial :: printer_default, printer_of
        procedure :: width => printer_width
    end type Printer

    type, implements(IWriter) :: Writer
    contains
        procedure :: lines => writer_lines
    end type Writer

    type, implements(IClient) :: Client
        private
        integer :: n = 0
    contains
        initial :: init_client
        procedure :: serve => client_serve
    end type Client

    type, implements(ILogger) :: DoubleLogger
        private
        integer :: lv = 0
    contains
        initial :: init_double
        procedure :: level => double_level
    end type DoubleLogger

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
    end interface

contains

    function printer_default() result(self)
        type(Printer) :: self
        self%w = 80
    end function printer_default

    function printer_of{INumeric :: T}(w) result(self)
        type(T), intent(in) :: w
        type(Printer) :: self
        self%w = whole(w)
    end function printer_of

    ! The integer part of a nonnegative value of a numeric type.
    integer function whole{INumeric :: T}(x) result(k)
        type(T), intent(in) :: x
        k = 0
        do while (T(k + 1) <= x)
            k = k + 1
        end do
    end function whole

    integer function printer_width(self)
        class(Printer), intent(in) :: self
        printer_width = self%w
    end function printer_width

    integer function writer_lines(self)
        class(Writer), intent(in) :: self
        writer_lines = 24
    end function writer_lines

    function init_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = logger%level() + 1
    end function init_client

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%n
    end function client_serve

    function init_double(printer, writer) result(self)
        class(IPrinter), intent(in) :: printer
        class(IWriter), intent(in) :: writer
        type(DoubleLogger) :: self
        self%lv = printer%width() + writer%lines()
    end function init_double

    integer function double_level(self)
        class(DoubleLogger), intent(in) :: self
        double_level = self%lv
    end function double_level

    ! Hand-written constructors, as named procedures.
    function make_printer() result(res)
        type(Printer) :: res
        res = Printer(100)
    end function make_printer

    function make_client(logger) result(res)
        class(ILogger), intent(in) :: logger
        type(Client) :: res
        res = Client(logger)
    end function make_client

    function make_double_logger(printer, writer) result(res)
        class(IPrinter), intent(in) :: printer
        class(IWriter), intent(in) :: writer
        type(DoubleLogger) :: res
        res = DoubleLogger(printer, writer)
    end function make_double_logger

end module traits_generic_init_01_app

! The type-erasing factory, here recording what each initializer was given.
module traits_generic_init_01_factory
    use traits_generic_init_01_app, only: ctor0, ctor1, ctor2
    implicit none
    private
    public :: Factory

    type :: Factory
        private
        character(:), allocatable :: kind
        integer :: arity = -1
        integer :: made = 0
    contains
        initial :: init0, init1, init2
        procedure :: describe, nargs, made_value
    end type Factory

contains

    ! The constructor is called: U is known in the instance.
    function init0{U}(ctor) result(self)
        procedure(ctor0{U}) :: ctor
        type(Factory) :: self
        type(U) :: obj
        obj = ctor()
        self%kind = type_name{U}() // "()"
        self%arity = 0
    end function init0

    function init1{Trait :: T1, U}(ctor) result(self)
        procedure(ctor1{T1,U}) :: ctor
        type(Factory) :: self
        self%kind = type_name{U}() // "(" // type_name{T1}() // ")"
        self%arity = 1
    end function init1

    function init2{Trait :: T1, Trait :: T2, U}(ctor) result(self)
        procedure(ctor2{T1,T2,U}) :: ctor
        type(Factory) :: self
        self%kind = type_name{U}() // "(" // type_name{T1}() // "," // &
            type_name{T2}() // ")"
        self%arity = 2
    end function init2

    function describe(self) result(r)
        class(Factory), intent(in) :: self
        character(:), allocatable :: r
        r = self%kind
    end function describe

    integer function nargs(self)
        class(Factory), intent(in) :: self
        nargs = self%arity
    end function nargs

    integer function made_value(self)
        class(Factory), intent(in) :: self
        made_value = self%made
    end function made_value

end module traits_generic_init_01_factory

! The container of Sect. 4.5: Factory(ctor) inside generic procedures,
! whose dummy procedures have interfaces instantiated with their parameters.
module traits_generic_init_01_container
    use traits_generic_init_01_app, only: ctor0, ctor1, ctor2
    use traits_generic_init_01_factory, only: Factory
    implicit none
    private
    public :: Container

    type :: Container
        integer :: n = 0
        character(len=64) :: keys(8)
        type(Factory) :: facts(8)
    contains
        generic :: register => register0, register1, register2
        procedure :: register0, register1, register2
    end type Container

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}()
        self%facts(self%n) = Factory(ctor)
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}()
        self%facts(self%n) = Factory(ctor)
    end subroutine register1

    subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor2{T1,T2,U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}()
        self%facts(self%n) = Factory(ctor)
    end subroutine register2

end module traits_generic_init_01_container

! A non-generic initializer overlapping a generic one, generic initializers
! with data arguments, keywords, and one bound in an implements statement.
! An initializer that calls the constructor it is given with a real argument.
module traits_generic_init_01_num
    use traits_generic_init_01_app, only: IClient, ILogger, ctor1, INumeric, whole
    implicit none
    private
    public :: Num, Gauge, Service

    type :: Num
        integer :: k = 0
        character(len=16) :: from = ""
    contains
        initial :: num_from_int, num_from
    end type Num

    type :: Gauge
        integer :: v = 0
        integer :: scale = 1
    end type Gauge

    implements :: Gauge
        initial :: gauge_of
    end implements Gauge

    type :: Service
        integer :: served = 0
        character(len=32) :: made = ""
    contains
        initial :: service_from
    end type Service

contains

    function num_from_int(x) result(self)
        integer, intent(in) :: x
        type(Num) :: self
        self%k = -x
        self%from = "integer"
    end function num_from_int

    function num_from{INumeric :: T}(x) result(self)
        type(T), intent(in) :: x
        type(Num) :: self
        self%k = whole(x)
        self%from = type_name{T}()
    end function num_from

    function gauge_of{INumeric :: T}(x, scale) result(self)
        type(T), intent(in) :: x
        integer, intent(in) :: scale
        type(Gauge) :: self
        self%v = whole(x) * scale
        self%scale = scale
    end function gauge_of

    function service_from{Trait :: T1, IClient :: U}(ctor, a) result(self)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(Service) :: self
        type(U) :: obj
        obj = ctor(a)
        self%served = obj%serve()
        self%made = type_name{U}() // "(" // type_name{T1}() // ")"
    end function service_from

end module traits_generic_init_01_num

program traits_generic_init_01
    use traits_generic_init_01_app, only: ILogger, IPrinter, IWriter, IClient, &
        Printer, Writer, Client, DoubleLogger, make_printer, make_client, &
        make_double_logger
    use traits_generic_init_01_factory, only: Factory
    use traits_generic_init_01_container, only: Container
    use traits_generic_init_01_num, only: Num, Gauge, Service
    implicit none
    type(Factory) :: f
    type(Container) :: cont
    type(Printer) :: p
    type(Num) :: a
    type(Gauge) :: g
    type(Service) :: s
    class(ILogger), allocatable :: lg
    integer :: i, arity(7)

    ! Factory's initializer is selected by the arity of the interface of
    ! the named constructor, and its parameters inferred from it.
    f = Factory(make_printer)
    if (f%nargs() /= 0) error stop 1
    if (f%describe() /= "Printer()") error stop 2
    f = Factory(make_client)
    if (f%nargs() /= 1) error stop 3
    if (f%describe() /= "Client(ILogger)") error stop 4
    f = Factory(make_double_logger)
    if (f%nargs() /= 2) error stop 5
    if (f%describe() /= "DoubleLogger(IPrinter,IWriter)") error stop 6
    f = Factory(ctor=make_client)
    if (f%describe() /= "Client(ILogger)") error stop 7

    ! Through generic procedures forwarding their dummy procedures, with
    ! named constructors and with type names (E3, E4, E5, E6, E8, E9).
    call cont%register{IPrinter}(make_printer)
    call cont%register{IClient}(make_client)
    call cont%register{ILogger}(make_double_logger)
    call cont%register{IClient}(Client)
    call cont%register{ILogger}(DoubleLogger)
    call cont%register{IWriter}(Writer)
    call cont%register{IPrinter}(Printer)
    if (cont%n /= 7) error stop 8
    if (cont%keys(1) /= "IPrinter" .or. cont%facts(1)%describe() /= "Printer()") error stop 9
    if (cont%keys(2) /= "IClient" .or. cont%facts(2)%describe() /= "Client(ILogger)") &
        error stop 10
    if (cont%facts(3)%describe() /= "DoubleLogger(IPrinter,IWriter)") error stop 11
    if (cont%facts(4)%describe() /= "Client(ILogger)") error stop 12
    if (cont%facts(5)%describe() /= "DoubleLogger(IPrinter,IWriter)") error stop 13
    if (cont%facts(6)%describe() /= "Writer()") error stop 14
    if (cont%facts(7)%describe() /= "Printer()") error stop 15
    arity = [0, 1, 2, 1, 2, 0, 0]
    do i = 1, 7
        if (cont%facts(i)%nargs() /= arity(i)) error stop 16
    end do

    ! A non-generic initializer overlapping a generic one is preferred.
    a = Num(3)
    if (a%k /= -3 .or. a%from /= "integer") error stop 17
    a = Num(2.5)
    if (a%k /= 2 .or. a%from /= "real(4)") error stop 18
    a = Num(x=7.5d0)
    if (a%k /= 7 .or. a%from /= "real(8)") error stop 19
    ! The structure constructor, which no initializer accepts: integer(8)
    ! is not a member of INumeric.
    a = Num(9_8)
    if (a%k /= 9 .or. a%from /= "") error stop 20
    a = Num(5, "manual")
    if (a%k /= 5 .or. a%from /= "manual") error stop 21

    ! A generic initializer bound in an implements statement.
    g = Gauge(1.5, 4)
    if (g%v /= 4 .or. g%scale /= 4) error stop 22
    g = Gauge(scale=3, x=2)
    if (g%v /= 6 .or. g%scale /= 3) error stop 23
    g = Gauge(5)
    if (g%v /= 5 .or. g%scale /= 1) error stop 24

    ! A generic initializer and a non-generic one of an implementing type.
    p = Printer(132)
    if (p%width() /= 132) error stop 25
    p = Printer(64.9d0)
    if (p%width() /= 64) error stop 26
    p = Printer()
    if (p%width() /= 80) error stop 27

    ! The initializer calls the constructor it is given.
    allocate(lg, source=DoubleLogger(Printer(10), Writer()))
    s = Service(make_client, lg)
    if (s%served /= 35 .or. s%made /= "Client(ILogger)") error stop 28
    s = Service(Client, lg)
    if (s%served /= 35 .or. s%made /= "Client(ILogger)") error stop 29
    print *, "ok"
end program traits_generic_init_01
