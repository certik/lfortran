! Type names as procedure designators (DI extension E3). A type name as an
! actual argument associated with a dummy procedure, or as the target of a
! procedure-pointer assignment, designates the type's initializer whose
! interface matches: an `initial ::` binding, also a private procedure, or a
! specific of a standard generic interface with the type's name. Otherwise
! it designates the structure constructor with as many positional
! component values as the interface has dummy arguments, if that reference
! is valid where the name appears: the omitted components have default
! initialization or are allocatable, even if private. With a dummy whose
! interface is an instance of a generic abstract interface, the designated
! procedure binds the generic parameters (E4), also after leading explicit
! type arguments (E5).
! GFortran does not accept this LFortran extension.

! Sect. 3.4 of the extension: a type whose only component is private and
! default-initialized, used from another module through Counter().
module traits_type_designator_01_counter
    implicit none
    private
    public :: ICounter, Counter

    abstract interface :: ICounter
        integer function count(self)
            type(itself), intent(in), pass :: self
        end function count
    end interface ICounter

    type, implements(ICounter) :: Counter
        private
        integer :: n = 3
    contains
        procedure :: count => counter_count
    end type Counter

contains

    integer function counter_count(self)
        class(Counter), intent(in) :: self
        counter_count = self%n
    end function counter_count

end module traits_type_designator_01_counter

! A generic type, designated with explicit type arguments.
module traits_type_designator_01_box
    implicit none
    private
    public :: Box

    type :: Box{T}
        type(T) :: v
    end type Box

end module traits_type_designator_01_box

module traits_type_designator_01_m
    use traits_type_designator_01_box, only: Box
    implicit none
    private
    public :: ILogger, IPrinter, IClient, Printer, Logger, Client, Bag, Pair, &
        Point, mk_printer, mk_logger, mk_client, mk_bag, mk_pair1, mk_pair2, &
        mk_point, ctor0, ctor1, use_printer, use_logger, use_client, use_bag, &
        use_pair1, use_pair2, use_point, run_logger, build0, build1, &
        register1, Registry, local_designators, Holder, mk_box, use_box

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

    ! No components: its structure constructor Printer() is its initializer.
    type, implements(IPrinter) :: Printer
    contains
        procedure :: width => printer_width
    end type Printer

    ! A private component, and a private initializer.
    type, implements(ILogger) :: Logger
        private
        integer :: lv = 5
    contains
        initial :: init_logger
        procedure :: level => logger_level
    end type Logger

    ! A private component that the initializer sets from a trait object.
    type, implements(IClient) :: Client
        private
        integer :: n = 0
    contains
        initial :: init_client
        procedure :: serve => client_serve
    end type Client

    ! Private allocatable components, omitted by Bag().
    type :: Bag
        private
        integer, allocatable :: items(:)
        character(:), allocatable :: label
    contains
        procedure :: empty => bag_empty
    end type Bag

    ! Public components, the second default-initialized.
    type :: Pair
        integer :: a
        integer :: b = 20
    end type Pair

    ! A standard generic interface with the type's name.
    type :: Point
        real :: x = 0, y = 0
    end type Point

    interface Point
        module procedure make_point
    end interface Point

    abstract interface
        function mk_printer() result(r)
            import :: Printer
            type(Printer) :: r
        end function mk_printer

        function mk_logger(level) result(r)
            import :: Logger
            integer, intent(in) :: level
            type(Logger) :: r
        end function mk_logger

        function mk_client(logger) result(r)
            import :: ILogger, Client
            class(ILogger), intent(in) :: logger
            type(Client) :: r
        end function mk_client

        function mk_bag() result(r)
            import :: Bag
            type(Bag) :: r
        end function mk_bag

        function mk_pair1(a) result(r)
            import :: Pair
            integer, intent(in) :: a
            type(Pair) :: r
        end function mk_pair1

        function mk_pair2(a, b) result(r)
            import :: Pair
            integer, intent(in) :: a, b
            type(Pair) :: r
        end function mk_pair2

        function mk_point(x) result(r)
            import :: Point
            real, intent(in) :: x
            type(Point) :: r
        end function mk_point

        function mk_box(x) result(r)
            import :: Box
            real, intent(in) :: x
            type(Box{real}) :: r
        end function mk_box

        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    type :: Registry
        integer :: last = 0
    contains
        procedure :: register0 => registry_register0
        procedure :: register1 => registry_register1
        procedure, pass(self) :: take => registry_take
        procedure, nopass :: count_logger
    end type Registry

    ! A procedure-pointer component.
    type :: Holder
        procedure(mk_logger), pointer, nopass :: make => null()
    end type Holder

contains

    integer function printer_width(self)
        class(Printer), intent(in) :: self
        printer_width = 80
    end function printer_width

    function init_logger(level) result(self)
        integer, intent(in) :: level
        type(Logger) :: self
        self%lv = 10 * level
    end function init_logger

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    function init_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = logger%level() + 1
    end function init_client

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%n
    end function client_serve

    logical function bag_empty(self)
        class(Bag), intent(in) :: self
        bag_empty = .not. allocated(self%items) .and. .not. allocated(self%label)
    end function bag_empty

    function make_point(x) result(p)
        real, intent(in) :: x
        type(Point) :: p
        p%x = x
        p%y = 2 * x
    end function make_point

    integer function use_printer(f)
        procedure(mk_printer) :: f
        type(Printer) :: p
        p = f()
        use_printer = p%width()
    end function use_printer

    integer function use_logger(f, level)
        procedure(mk_logger) :: f
        integer, intent(in) :: level
        type(Logger) :: l
        l = f(level)
        use_logger = l%level()
    end function use_logger

    integer function use_client(f, logger)
        procedure(mk_client) :: f
        class(ILogger), intent(in) :: logger
        type(Client) :: c
        c = f(logger)
        use_client = c%serve()
    end function use_client

    logical function use_bag(f)
        procedure(mk_bag) :: f
        type(Bag) :: b
        b = f()
        use_bag = b%empty()
    end function use_bag

    integer function use_pair1(f, a)
        procedure(mk_pair1) :: f
        integer, intent(in) :: a
        type(Pair) :: p
        p = f(a)
        use_pair1 = 100 * p%a + p%b
    end function use_pair1

    integer function use_pair2(f, a, b)
        procedure(mk_pair2) :: f
        integer, intent(in) :: a, b
        type(Pair) :: p
        p = f(a, b)
        use_pair2 = 100 * p%a + p%b
    end function use_pair2

    real function use_point(f, x)
        procedure(mk_point) :: f
        real, intent(in) :: x
        type(Point) :: p
        p = f(x)
        use_point = p%x + p%y
    end function use_point

    subroutine run_logger(f, level, out)
        procedure(mk_logger) :: f
        integer, intent(in) :: level
        integer, intent(out) :: out
        out = use_logger(f, level)
    end subroutine run_logger

    function build0{U}(ctor) result(r)
        procedure(ctor0{U}) :: ctor
        type(U) :: r
        r = ctor()
    end function build0

    function build1{Trait :: T1, U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(U) :: r
        r = ctor(a)
    end function build1

    ! P given, T1 and U inferred from the designated initializer.
    function register1{Trait :: P, Trait :: T1, P :: U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        class(P), allocatable :: r
        r = ctor(a)
    end function register1

    subroutine registry_register0{Trait :: P, P :: U}(self, ctor)
        class(Registry), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        class(P), allocatable :: obj
        obj = ctor()
        self%last = len(type_name{P}()) + 10 * len(type_name{U}())
    end subroutine registry_register0

    subroutine registry_register1{Trait :: P, Trait :: T1, P :: U}(self, ctor, a)
        class(Registry), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        class(P), allocatable :: obj
        obj = ctor(a)
        self%last = 100 * len(type_name{U}()) + len(type_name{T1}())
    end subroutine registry_register1

    ! A type-bound procedure, whose passed object is not the first dummy.
    subroutine registry_take(f, self, level)
        procedure(mk_logger) :: f
        class(Registry), intent(inout) :: self
        integer, intent(in) :: level
        self%last = use_logger(f, level)
    end subroutine registry_take

    integer function count_logger(f)
        procedure(mk_logger) :: f
        count_logger = use_logger(f, 1) + 1
    end function count_logger

    real function use_box(f, x)
        procedure(mk_box) :: f
        real, intent(in) :: x
        type(Box{real}) :: b
        b = f(x)
        use_box = b%v
    end function use_box

    ! Inside the module the private components are accessible, so the
    ! structure constructor of Logger with one value is admissible too,
    ! but the initializer matches first.
    integer function local_designators() result(r)
        procedure(mk_logger), pointer :: p
        p => Logger
        r = use_logger(Logger, 2) + use_logger(p, 3)
    end function local_designators

end module traits_type_designator_01_m

module traits_type_designator_01_user
    use traits_type_designator_01_counter, only: ICounter, Counter
    implicit none
    private
    public :: mk_counter, counted

    abstract interface
        function mk_counter() result(r)
            import :: Counter
            type(Counter) :: r
        end function mk_counter
    end interface

contains

    integer function use_counter(f)
        procedure(mk_counter) :: f
        type(Counter) :: c
        c = f()
        use_counter = c%count()
    end function use_counter

    ! Counter() outside the module that declares Counter.
    integer function counted()
        counted = use_counter(Counter) + use_counter(Counter)
    end function counted

end module traits_type_designator_01_user

program traits_type_designator_01
    use traits_type_designator_01_m
    use traits_type_designator_01_user
    use traits_type_designator_01_box, only: Box
    implicit none
    type(Logger) :: lg0
    class(ILogger), allocatable :: lg
    class(IClient), allocatable :: cl
    type(Printer) :: pr
    type(Client) :: c
    type(Registry) :: reg
    procedure(mk_logger), pointer :: pl
    procedure(mk_printer), pointer :: pp => null()
    procedure(ctor1{ILogger, Client}), pointer :: pc
    type(Holder) :: hold
    integer :: k

    ! Initializers, the second one private.
    if (use_logger(Logger, 4) /= 40) error stop 1
    lg0 = Logger(2)
    lg = lg0
    if (use_client(Client, lg) /= 21) error stop 2
    call run_logger(Logger, 6, k)
    if (k /= 60) error stop 3

    ! Structure constructors.
    if (use_printer(Printer) /= 80) error stop 4
    if (.not. use_bag(Bag)) error stop 5
    if (use_pair1(Pair, 7) /= 720) error stop 6
    if (use_pair2(Pair, 7, 8) /= 708) error stop 7
    if (counted() /= 6) error stop 8

    ! A standard generic interface with the type's name.
    if (abs(use_point(Point, 1.5) - 4.5) > 1e-6) error stop 9

    ! Procedure-pointer targets.
    pl => Logger
    if (use_logger(pl, 3) /= 30) error stop 10
    pp => Printer
    pr = pp()
    if (pr%width() /= 80) error stop 11
    pc => Client
    c = pc(lg)
    if (c%serve() /= 21) error stop 12

    ! Inference through a generic dummy procedure (E4), and with P given (E5).
    pr = build0(Printer)
    if (pr%width() /= 80) error stop 13
    c = build1(Client, lg)
    if (c%serve() /= 21) error stop 14
    cl = register1{IClient}(Client, lg)
    if (cl%serve() /= 21) error stop 15
    call reg%register1{IClient}(Client, lg)
    if (reg%last /= 607) error stop 16
    call reg%register0{IPrinter}(Printer)
    if (reg%last /= 8 + 70) error stop 17
    reg%last = 0
    call reg%register1{IClient}(ctor=Client, a=lg)
    if (reg%last /= 607) error stop 18

    if (local_designators() /= 50) error stop 19

    ! Type-bound procedures, with a passed object and without.
    call reg%take(Logger, 7)
    if (reg%last /= 70) error stop 20
    if (reg%count_logger(Logger) /= 11) error stop 21

    ! A procedure-pointer component: a pointer assignment, and a structure
    ! constructor positional and by keyword.
    hold%make => Logger
    lg0 = hold%make(5)
    if (lg0%level() /= 50) error stop 22
    hold = Holder(Logger)
    lg0 = hold%make(6)
    if (lg0%level() /= 60) error stop 23
    hold = Holder(make=Logger)
    lg0 = hold%make(8)
    if (lg0%level() /= 80) error stop 24

    ! An instance of a generic type.
    if (abs(use_box(Box{real}, 2.5) - 2.5) > 1e-6) error stop 25

    print '(a)', 'traits_type_designator_01 ok'
end program traits_type_designator_01
