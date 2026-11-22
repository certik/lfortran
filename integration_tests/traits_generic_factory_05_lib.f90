! The modules of traits_generic_factory_04, compiled separately from their
! client traits_generic_factory_05. The module files of the container
! module reference what it uses of the factory module through imports: the
! generic initializers of `~factory` (E6, E9), the conformance of a generic
! factory type's definition by which the instances of init0/1/2 that
! register0/1/2 forward box a symbolic instance, and the trait contracts
! that the components of type(Factory) name in the erased copy of the
! container's generic `resolve` (E10).
! GFortran does not accept this LFortran extension.
module traits_generic_factory_05_resolver
    implicit none
    private
    public :: IResolver

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), pass, intent(in) :: self
            class(P), allocatable :: res
        end function resolve
    end interface
end module traits_generic_factory_05_resolver

module traits_generic_factory_05_ifactory
    use traits_generic_factory_05_resolver, only: IResolver
    implicit none
    private
    public :: IFactory

    abstract interface :: IFactory
        function create(self, c) result(res)
            type(itself), pass, intent(in) :: self
            class(IResolver), intent(in) :: c
            class(*), allocatable :: res
        end function create
    end interface
end module traits_generic_factory_05_ifactory

module traits_generic_factory_05_interfaces
    implicit none
    private
    public :: ctor0, ctor1, ctor2

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
end module traits_generic_factory_05_interfaces

module traits_generic_factory_05_traits
    implicit none
    private
    public :: ILogger, IClient, IPrinter, IWriter

    abstract interface :: ILogger
        integer function level(self)
            type(itself), pass, intent(in) :: self
        end function level
    end interface

    abstract interface, extends(ILogger) :: IClient
    end interface

    abstract interface :: IPrinter
        integer function printout(self)
            type(itself), pass, intent(in) :: self
        end function printout
    end interface

    abstract interface :: IWriter
        integer function writeout(self)
            type(itself), pass, intent(in) :: self
        end function writeout
    end interface
end module traits_generic_factory_05_traits

module traits_generic_factory_05_types
    use traits_generic_factory_05_traits, only: ILogger, IClient, IPrinter, IWriter
    implicit none
    private
    public :: Client, SingleLogger, DoubleLogger, Printer, Writer, make_client, &
        make_single_logger, make_double_logger, make_printer, make_writer

    type, implements(IClient) :: Client
        private
        class(ILogger), allocatable :: logger
    contains
        procedure :: level => client_level
    end type Client

    type, implements(ILogger) :: SingleLogger
        private
        class(IPrinter), allocatable :: printer
    contains
        procedure :: level => single_level
    end type SingleLogger

    type, implements(ILogger) :: DoubleLogger
        private
        class(IPrinter), allocatable :: printer
        class(IWriter), allocatable :: writer
    contains
        procedure :: level => double_level
    end type DoubleLogger

    type, implements(IPrinter) :: Printer
        integer :: code = 3
    contains
        procedure :: printout
    end type Printer

    type, implements(IWriter) :: Writer
        integer :: code = 4
    contains
        procedure :: writeout
    end type Writer

contains

    function make_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%logger = logger
    end function make_client

    function make_single_logger(printer) result(self)
        class(IPrinter), intent(in) :: printer
        type(SingleLogger) :: self
        self%printer = printer
    end function make_single_logger

    function make_double_logger(printer, writer) result(self)
        class(IPrinter), intent(in) :: printer
        class(IWriter), intent(in) :: writer
        type(DoubleLogger) :: self
        self%printer = printer
        self%writer = writer
    end function make_double_logger

    function make_printer() result(self)
        type(Printer) :: self
        self%code = 3
    end function make_printer

    function make_writer() result(self)
        type(Writer) :: self
        self%code = 4
    end function make_writer

    integer function client_level(self)
        class(Client), intent(in) :: self
        client_level = 1000 + self%logger%level()
    end function client_level

    integer function single_level(self)
        class(SingleLogger), intent(in) :: self
        single_level = self%printer%printout()
    end function single_level

    integer function double_level(self)
        class(DoubleLogger), intent(in) :: self
        double_level = 10 * self%printer%printout() + self%writer%writeout()
    end function double_level

    integer function printout(self)
        class(Printer), intent(in) :: self
        printout = self%code
    end function printout

    integer function writeout(self)
        class(Writer), intent(in) :: self
        writeout = self%code
    end function writeout

end module traits_generic_factory_05_types

module traits_generic_factory_05_factory
    use traits_generic_factory_05_ifactory, only: IFactory
    use traits_generic_factory_05_resolver, only: IResolver
    use traits_generic_factory_05_interfaces, only: ctor0, ctor1, ctor2
    implicit none
    private
    public :: Factory

    ! The type-erasing decorator.
    type, sealed, implements(IFactory) :: Factory
        private
        class(IFactory), allocatable :: box
    contains
        initial :: init0, init1, init2
        procedure :: create
    end type Factory

    ! The helper types for type erasure, one per initializer arity.
    type, sealed, implements(IFactory) :: Factory0{U}
        private
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    contains
        procedure :: create => create0
    end type Factory0

    type, sealed, implements(IFactory) :: Factory1{Trait :: T1, U}
        private
        procedure(ctor1{T1,U}), pointer, nopass :: ctor => null()
    contains
        procedure :: create => create1
    end type Factory1

    type, sealed, implements(IFactory) :: Factory2{Trait :: T1, Trait :: T2, U}
        private
        procedure(ctor2{T1,T2,U}), pointer, nopass :: ctor => null()
    contains
        procedure :: create => create2
    end type Factory2

contains

    function init0{U}(ctor) result(self)
        procedure(ctor0{U}) :: ctor
        type(Factory) :: self
        self%box = Factory0(ctor)
    end function init0

    function init1{Trait :: T1, U}(ctor) result(self)
        procedure(ctor1{T1,U}) :: ctor
        type(Factory) :: self
        self%box = Factory1(ctor)
    end function init1

    function init2{Trait :: T1, Trait :: T2, U}(ctor) result(self)
        procedure(ctor2{T1,T2,U}) :: ctor
        type(Factory) :: self
        self%box = Factory2(ctor)
    end function init2

    function create(self, c) result(res)
        type(Factory), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%box%create(c)
    end function create

    function create0(self, c) result(res)
        type(Factory0{U}), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%ctor()
    end function create0

    function create1(self, c) result(res)
        type(Factory1{T1,U}), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%ctor(c%resolve{T1}())
    end function create1

    function create2(self, c) result(res)
        type(Factory2{T1,T2,U}), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%ctor(c%resolve{T1}(), c%resolve{T2}())
    end function create2

end module traits_generic_factory_05_factory

module traits_generic_factory_05_container
    use traits_generic_factory_05_resolver, only: IResolver
    use traits_generic_factory_05_interfaces, only: ctor0, ctor1, ctor2
    use traits_generic_factory_05_factory, only: Factory
    implicit none
    private
    public :: Container

    ! The factories, keyed by the qualified name of their trait.
    type, sealed, implements(IResolver) :: Container
        integer :: n = 0
        character(len=64) :: keys(8)
        type(Factory) :: facts(8)
    contains
        generic :: register => register0, register1, register2
        procedure :: register0, register1, register2
        procedure :: resolve
    end type Container

contains

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}(qualified=.true.)
        self%facts(self%n) = Factory(ctor)
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}(qualified=.true.)
        self%facts(self%n) = Factory(ctor)
    end subroutine register1

    subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor2{T1,T2,U}) :: ctor
        self%n = self%n + 1
        self%keys(self%n) = type_name{P}(qualified=.true.)
        self%facts(self%n) = Factory(ctor)
    end subroutine register2

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(*), allocatable :: obj
        integer :: i
        do i = self%n, 1, -1
            if (trim(self%keys(i)) == type_name{P}(qualified=.true.)) then
                obj = self%facts(i)%create(self)
                select type (obj)
                class is (P)
                    res = obj
                class default
                    error stop "the registered type does not implement the trait"
                end select
                return
            end if
        end do
        error stop "no registration"
    end function resolve

end module traits_generic_factory_05_container
