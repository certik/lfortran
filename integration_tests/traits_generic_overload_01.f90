! Overloading of generic procedures (DI extension E6). A generic interface or
! a generic binding may have generic specific procedures. A reference is
! resolved by trying the non-generic specifics first; otherwise the one
! generic specific whose leading parameters admit the explicit type
! arguments, whose other parameters inference determines, also through
! dummy procedures and type names (E3, E4), and whose constraints hold (E2)
! is instantiated. Generic specifics must be distinguishable, with generic
! parameters as wildcards over their constraints and dummy procedures
! distinguished by their interfaces; a non-generic specific may overlap a
! generic one.
! GFortran does not accept this LFortran extension.

! The container of Sect. 4.5 of the extension, recording each registration.
module traits_generic_overload_01_di
    implicit none
    private
    public :: ILogger, IPrinter, IWriter, IClient, Printer, Writer, Client, &
        DoubleLogger, Container, ctor0, ctor1, ctor2, build, Counted

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

    ! No components: Printer() and Writer() are their initializers.
    type, implements(IPrinter) :: Printer
    contains
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

    ! A type with a component, constructed by Counted(n).
    type :: Counted
        integer :: n = 0
    end type Counted

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

        function make1{U}(n) result(res)
            integer, intent(in) :: n
            type(U) :: res
        end function make1
    end interface

    type :: Container
        integer :: n = 0
        character(len=64) :: keys(8)
        integer :: arity(8) = -1
    contains
        generic :: register => register0, register1, register2
        procedure :: register0, register1, register2
    end type Container

    ! Free generic specifics told apart by the arity of a dummy procedure.
    interface build
        module procedure build0, build1
    end interface build

contains

    integer function printer_width(self)
        class(Printer), intent(in) :: self
        printer_width = 80
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

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        class(P), allocatable :: obj
        obj = ctor()
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}(qualified=.true.) // "=" // type_name{U}() // "()"
        self%arity(self%n) = 0
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}() // "=" // type_name{U}() // "(" // &
            type_name{T1}() // ")"
        self%arity(self%n) = 1
    end subroutine register1

    subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
        class(Container), intent(inout) :: self
        procedure(ctor2{T1,T2,U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}() // "=" // type_name{U}() // "(" // &
            type_name{T1}() // "," // type_name{T2}() // ")"
        self%arity(self%n) = 2
    end subroutine register2

    function build0{U}(ctor) result(r)
        procedure(ctor0{U}) :: ctor
        type(U) :: r
        r = ctor()
    end function build0

    function build1{U}(ctor, n) result(r)
        procedure(make1{U}) :: ctor
        integer, intent(in) :: n
        type(U) :: r
        r = ctor(n)
    end function build1

end module traits_generic_overload_01_di

! Free generic interfaces: a non-generic specific overlapping a generic one,
! and generic specifics told apart by rank or by data type.
module traits_generic_overload_01_num
    implicit none
    private
    public :: INumeric, norm, total, describe, pick

    abstract interface :: INumeric
        integer | real(4) | real(8)
    end interface INumeric

    abstract interface :: IInteger
        integer(*)
    end interface IInteger

    abstract interface :: IReal
        real(4) | real(8)
    end interface IReal

    interface norm
        module procedure norm_generic, norm_real64
    end interface norm

    interface total
        module procedure total_scalar, total_array
    end interface total

    interface describe
        module procedure describe_integer, describe_real
    end interface describe

    interface pick
        module procedure pick_count, pick_flag
    end interface pick

contains

    integer function norm_generic{INumeric :: T}(x) result(r)
        type(T), intent(in) :: x
        r = len(type_name{T}())
    end function norm_generic

    integer function norm_real64(x) result(r)
        real(8), intent(in) :: x
        r = -1
    end function norm_real64

    integer function total_scalar{INumeric :: T}(x) result(r)
        type(T), intent(in) :: x
        r = 1
    end function total_scalar

    integer function total_array{INumeric :: T}(x) result(r)
        type(T), intent(in) :: x(:)
        r = 100 + size(x)
    end function total_array

    integer function describe_integer{IInteger :: T}(x) result(r)
        type(T), intent(in) :: x
        r = 10
    end function describe_integer

    integer function describe_real{IReal :: T}(x) result(r)
        type(T), intent(in) :: x
        r = 20
    end function describe_real

    integer function pick_count{U}(x, n) result(r)
        type(U), intent(in) :: x
        integer, intent(in) :: n
        r = n
    end function pick_count

    integer function pick_flag{U}(x, flag) result(r)
        type(U), intent(in) :: x
        logical, intent(in) :: flag
        r = merge(1000, 2000, flag)
    end function pick_flag

end module traits_generic_overload_01_num

! A generic binding and a generic interface of subroutines, each with a
! non-generic and generic specifics, also referenced with keywords and from
! a generic.
module traits_generic_overload_01_box
    implicit none
    private
    public :: IShow, Shown, Box, fwd, setv

    abstract interface :: IShow
        integer function show(self)
            type(itself), intent(in), pass :: self
        end function show
    end interface IShow

    type, implements(IShow) :: Shown
        integer :: k = 3
    contains
        procedure :: show => shown_show
    end type Shown

    abstract interface
        function maker{U}() result(res)
            type(U) :: res
        end function maker
    end interface

    type :: Box
        integer :: n = 0
    contains
        generic :: put => put_int, put_gen, put_ctor
        procedure :: put_int, put_gen, put_ctor
    end type Box

    interface setv
        module procedure setv_int, setv_gen
    end interface setv

contains

    integer function shown_show(self)
        class(Shown), intent(in) :: self
        shown_show = self%k
    end function shown_show

    subroutine put_int(self, v)
        class(Box), intent(inout) :: self
        integer, intent(in) :: v
        self%n = v
    end subroutine put_int

    subroutine put_gen{IShow :: T}(self, v)
        class(Box), intent(inout) :: self
        type(T), intent(in) :: v
        self%n = 100 + v%show()
    end subroutine put_gen

    subroutine put_ctor{Trait :: P, P :: U}(self, ctor)
        class(Box), intent(inout) :: self
        procedure(maker{U}) :: ctor
        class(P), allocatable :: o
        o = ctor()
        self%n = 1000 + len(type_name{U}())
    end subroutine put_ctor

    ! T forwarded to the generic specific put_gen.
    subroutine fwd{IShow :: T}(b, x)
        type(Box), intent(inout) :: b
        type(T), intent(in) :: x
        call b%put(x)
    end subroutine fwd

    subroutine setv_int(x, v)
        integer, intent(out) :: x
        integer, intent(in) :: v
        x = v
    end subroutine setv_int

    subroutine setv_gen{T}(x, v)
        type(T), intent(out) :: x
        type(T), intent(in) :: v
        x = v
    end subroutine setv_gen

end module traits_generic_overload_01_box

program traits_generic_overload_01
    use traits_generic_overload_01_di, only: ILogger, IPrinter, IWriter, IClient, &
        Printer, Writer, Client, DoubleLogger, Container, build, Counted
    use traits_generic_overload_01_num, only: norm, total, describe, pick
    use traits_generic_overload_01_box, only: IShow, Shown, Box, fwd, setv
    implicit none
    type(Container) :: cont
    type(Box) :: b
    type(Shown) :: s
    integer :: i
    real :: r
    type(Printer) :: p
    type(Counted) :: c
    real(8) :: v(3)

    ! P explicit, the rest inferred from the type name (E3, E4).
    call cont%register{IClient}(Client)
    call cont%register{ILogger}(DoubleLogger)
    call cont%register{IPrinter}(Printer)
    call cont%register{IWriter}(ctor=Writer)
    if (cont%n /= 4) error stop 1
    if (any(cont%arity(1:4) /= [1, 2, 0, 0])) error stop 2
    if (trim(cont%keys(1)) /= "IClient=Client(ILogger)") error stop 3
    if (trim(cont%keys(2)) /= "ILogger=DoubleLogger(IPrinter,IWriter)") error stop 4
    if (trim(cont%keys(3)) /= "traits_generic_overload_01_di::IPrinter=Printer()") error stop 5
    if (trim(cont%keys(4)) /= "traits_generic_overload_01_di::IWriter=Writer()") error stop 6

    ! A free generic interface, by the arity of the designated procedure.
    p = build(Printer)
    if (p%width() /= 80) error stop 7
    c = build(Counted, 7)
    if (c%n /= 7) error stop 8

    ! The non-generic specific is chosen for real(8), the generic one for
    ! the other members, and for real(8) with an explicit type argument.
    if (norm(1.0d0) /= -1) error stop 9
    if (norm(1.0) /= 7) error stop 10
    if (norm(2) /= 10) error stop 11
    if (norm{real(8)}(1.0d0) /= 7) error stop 12
    v = [1, 2, 3]
    if (norm(v(2)) /= -1) error stop 13

    ! Generic specifics told apart by rank and by data type.
    if (total(2.5) /= 1) error stop 14
    if (total(v) /= 103) error stop 15
    if (total([1, 2]) /= 102) error stop 16
    if (describe(3) /= 10) error stop 17
    if (describe(3_8) /= 10) error stop 18
    if (describe(1.5) /= 20) error stop 19
    if (describe(1.5d0) /= 20) error stop 20
    if (pick(1.0, 5) /= 5) error stop 21
    if (pick(p, .true.) /= 1000) error stop 22
    if (pick(x=c, flag=.false.) /= 2000) error stop 23

    ! Non-generic specifics first, then the generic ones.
    call b%put(5)
    if (b%n /= 5) error stop 24
    call b%put(v=6)
    if (b%n /= 6) error stop 25
    call b%put(s)
    if (b%n /= 103) error stop 26
    call b%put{IShow}(Shown)
    if (b%n /= 1005) error stop 27
    b%n = 0
    call fwd(b, s)
    if (b%n /= 103) error stop 28
    call setv(i, 4)
    if (i /= 4) error stop 29
    call setv(r, 2.5)
    if (r /= 2.5) error stop 30
    call setv(v=3, x=i)
    if (i /= 3) error stop 31
    call setv(x=r, v=1.5)
    if (r /= 1.5) error stop 32
    print *, "ok"
end program traits_generic_overload_01
