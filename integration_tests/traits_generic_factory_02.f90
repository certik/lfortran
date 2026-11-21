! Inference of a generic type's parameters from the actual arguments of its
! structure constructor (DI extension E8b): a procedure argument is matched
! against the interface of a procedure-pointer component, a generic interface
! instance over the type's parameters, by the rules of E4; a data argument
! binds as before. The type has a trait parameter (E1). The constructor is
! referenced with explicit and with inferred type arguments, in the module
! that defines the type and in a program, and inside a generic procedure
! whose parameters are the type arguments, as a constructor and in local
! declarations.
! GFortran does not accept this LFortran extension.
module traits_generic_factory_02_m
    implicit none
    private
    public :: ILogger, Logger, Client, Holder, make_client, make_logger, &
        explicit_holder, inferred_holder, build_with, make_box

    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    type, implements(ILogger) :: Logger
        integer :: lv = 5
    contains
        procedure :: level => logger_level
    end type Logger

    type :: Client
        integer :: n = 0
    end type Client

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    type :: Holder{Trait :: T1, U}
        type(U) :: first
        procedure(ctor1{T1, U}), pointer, nopass :: ctor => null()
    contains
        procedure :: run
    end type Holder

    type :: Box{U}
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    contains
        procedure :: get
    end type Box

contains

    function run(self, a) result(y)
        class(Holder{T1, U}), intent(in) :: self
        class(T1), intent(in) :: a
        type(U) :: y
        y = self%ctor(a)
    end function run

    function get(self) result(y)
        class(Box{U}), intent(in) :: self
        type(U) :: y
        y = self%ctor()
    end function get

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    function make_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = 2 * logger%level()
    end function make_client

    function make_logger() result(self)
        type(Logger) :: self
        self%lv = 8
    end function make_logger

    ! Instances in the module that defines the generic types.
    integer function explicit_holder(lg) result(n)
        class(ILogger), intent(in) :: lg
        type(Holder{ILogger, Client}) :: h
        type(Client) :: c
        h = Holder{ILogger, Client}(Client(1), make_client)
        c = h%run(lg)
        n = c%n + h%first%n
    end function explicit_holder

    integer function inferred_holder(lg) result(n)
        class(ILogger), intent(in) :: lg
        type(Client) :: c
        type(Logger) :: l
        associate (h => Holder(Client(2), make_client))
            c = h%run(lg)
            n = c%n + h%first%n
        end associate
        l = make_box(make_logger)
        n = n + 100 * l%lv
    end function inferred_holder

    ! The type arguments are the generic's parameters.
    function build_with{Trait :: T1, U}(ctor, first, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        type(U), intent(in) :: first
        class(T1), intent(in) :: a
        type(U) :: r
        type(Holder{T1, U}) :: h
        h = Holder(first, ctor)
        r = h%ctor(a)
    end function build_with

    function make_box{U}(ctor) result(r)
        procedure(ctor0{U}) :: ctor
        type(U) :: r
        type(Box{U}) :: b
        b = Box(ctor)
        r = b%ctor()
    end function make_box

end module traits_generic_factory_02_m

program traits_generic_factory_02
    use traits_generic_factory_02_m
    implicit none
    type(Holder{ILogger, Client}) :: h
    class(ILogger), allocatable :: lg
    type(Client) :: c
    type(Logger) :: l

    lg = Logger(7)
    if (explicit_holder(lg) /= 15) error stop 1
    if (inferred_holder(lg) /= 816) error stop 2

    ! Inferred and explicit, in a program.
    h = Holder(Client(3), make_client)
    c = h%run(lg)
    if (c%n /= 14 .or. h%first%n /= 3) error stop 3
    h = Holder{ILogger, Client}(Client(4), make_client)
    if (h%first%n /= 4) error stop 4

    ! Inside generic procedures.
    c = build_with(make_client, Client(9), lg)
    if (c%n /= 14) error stop 5
    l = make_box(make_logger)
    if (l%lv /= 8) error stop 6

    print '(a)', 'traits_generic_factory_02 ok'
end program traits_generic_factory_02
