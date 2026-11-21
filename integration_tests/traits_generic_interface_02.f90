! Procedure-pointer components whose interfaces are instances of generic
! abstract interfaces (DI extension E4) with concrete type arguments, in a
! non-generic derived type: set by pointer assignment and in a structure
! constructor, called through the component, and passed on as an actual
! procedure from which a generic procedure infers its parameters. A generic
! derived type has a component whose interface is an instance with the
! type's parameters, called through it in a type-bound procedure and passed
! on as an actual procedure.
! GFortran does not accept this LFortran extension.
module traits_generic_interface_02_m
    implicit none
    private
    public :: ILogger, INum, Logger, Client, Factory, Mapper, ctor0, ctor1, &
        map1, make_logger, make_client, half, twice, build1, apply_map

    abstract interface :: INum
        integer | real
    end interface INum

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

        function map1{T, U}(x) result(y)
            type(T), intent(in) :: x
            type(U) :: y
        end function map1
    end interface

    type :: Factory
        procedure(ctor0{Logger}), pointer, nopass :: make0 => null()
        procedure(ctor1{ILogger, Client}), pointer, nopass :: make1 => null()
        procedure(map1{integer, real(8)}), pointer, nopass :: f => null()
    end type Factory

    type :: Mapper{INum :: T, U}
        procedure(map1{T, U}), pointer, nopass :: f => null()
    contains
        procedure :: run
    end type Mapper

contains

    function run(self, x) result(y)
        class(Mapper{T, U}), intent(in) :: self
        type(T), intent(in) :: x
        type(U) :: y
        y = self%f(x)
    end function run

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    function make_logger() result(self)
        type(Logger) :: self
        self%lv = 11
    end function make_logger

    function make_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = 2 * logger%level()
    end function make_client

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

    function build1{Trait :: T1, U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(U) :: r
        r = ctor(a)
    end function build1

    function apply_map{T, U}(f, x) result(r)
        procedure(map1{T,U}) :: f
        type(T), intent(in) :: x
        type(U) :: r
        r = f(x)
    end function apply_map

end module traits_generic_interface_02_m

program traits_generic_interface_02
    use traits_generic_interface_02_m
    implicit none
    type(Factory) :: fac, fac2
    type(Logger) :: l
    type(Client) :: c
    class(ILogger), allocatable :: lg
    type(Mapper{integer, real(8)}) :: m
    type(Mapper{real, integer}) :: m2

    if (associated(fac%make1)) error stop 1
    fac%make0 => make_logger
    fac%make1 => make_client
    fac%f => half
    l = fac%make0()
    if (l%lv /= 11) error stop 2
    lg = l
    c = fac%make1(lg)
    if (c%n /= 22) error stop 3
    if (abs(fac%f(7) - 3.5d0) > 1d-12) error stop 4

    fac2 = Factory(make_logger, make_client, half)
    c = fac2%make1(lg)
    if (c%n /= 22) error stop 5

    ! A component as the actual procedure of a generic.
    c = build1(fac%make1, lg)
    if (c%n /= 22) error stop 6
    if (abs(apply_map(fac2%f, 3) - 1.5d0) > 1d-12) error stop 7

    m%f => half
    if (abs(m%f(3) - 1.5d0) > 1d-12) error stop 8
    if (abs(m%run(5) - 2.5d0) > 1d-12) error stop 9
    m2%f => twice
    if (m2%run(1.5) /= 3) error stop 10
    if (abs(apply_map(m%f, 9) - 4.5d0) > 1d-12) error stop 11

    print '(a)', 'traits_generic_interface_02 ok'
end program traits_generic_interface_02
