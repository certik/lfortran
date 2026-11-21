! The modules of the dependency injection container of
! traits_generic_factory_01, compiled separately from their client
! traits_generic_factory_03: the factories' module owns instances of its
! generic factory types with trait type arguments, and the program loads it
! and the generic helpers from module files.
! GFortran does not accept this LFortran extension.
module traits_generic_factory_03_resolver
    implicit none
    private
    public :: IResolver

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), pass, intent(in) :: self
            class(P), allocatable :: res
        end function resolve
    end interface
end module traits_generic_factory_03_resolver

module traits_generic_factory_03_ifactory
    use traits_generic_factory_03_resolver, only: IResolver
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
end module traits_generic_factory_03_ifactory

module traits_generic_factory_03_interfaces
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
end module traits_generic_factory_03_interfaces

module traits_generic_factory_03_traits
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
end module traits_generic_factory_03_traits

module traits_generic_factory_03_types
    use traits_generic_factory_03_traits, only: ILogger, IClient, IPrinter, IWriter
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
        print '(a)', 'Calling logger from client:'
        client_level = 1000 + self%logger%level()
    end function client_level

    integer function single_level(self)
        class(SingleLogger), intent(in) :: self
        print '(a)', 'logging by'
        single_level = self%printer%printout()
    end function single_level

    integer function double_level(self)
        class(DoubleLogger), intent(in) :: self
        print '(a)', 'logging by'
        double_level = 10 * self%printer%printout() + self%writer%writeout()
    end function double_level

    integer function printout(self)
        class(Printer), intent(in) :: self
        print '(a)', 'printing ...'
        printout = self%code
    end function printout

    integer function writeout(self)
        class(Writer), intent(in) :: self
        print '(a)', 'writing ...'
        writeout = self%code
    end function writeout

end module traits_generic_factory_03_types

module traits_generic_factory_03_factories
    use traits_generic_factory_03_ifactory, only: IFactory
    use traits_generic_factory_03_resolver, only: IResolver
    use traits_generic_factory_03_interfaces, only: ctor0, ctor1, ctor2
    use traits_generic_factory_03_traits, only: ILogger, IPrinter
    use traits_generic_factory_03_types, only: Client, SingleLogger, make_client, &
        make_single_logger
    implicit none
    private
    public :: make_factory0, make_factory1, make_factory2, client_factory, &
        single_logger_factory

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

    function make_factory0{U}(ctor) result(f)
        procedure(ctor0{U}) :: ctor
        class(IFactory), allocatable :: f
        f = Factory0(ctor)
    end function make_factory0

    function make_factory1{Trait :: T1, U}(ctor) result(f)
        procedure(ctor1{T1,U}) :: ctor
        class(IFactory), allocatable :: f
        f = Factory1(ctor)
    end function make_factory1

    function make_factory2{Trait :: T1, Trait :: T2, U}(ctor) result(f)
        procedure(ctor2{T1,T2,U}) :: ctor
        class(IFactory), allocatable :: f
        f = Factory2(ctor)
    end function make_factory2

    ! Instances in the module that defines the generic types, with explicit
    ! and with inferred type arguments.
    function client_factory() result(f)
        class(IFactory), allocatable :: f
        f = Factory1{ILogger, Client}(make_client)
    end function client_factory

    function single_logger_factory() result(f)
        class(IFactory), allocatable :: f
        type(Factory1{IPrinter, SingleLogger}) :: g
        g = Factory1(make_single_logger)
        f = g
    end function single_logger_factory

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

end module traits_generic_factory_03_factories

module traits_generic_factory_03_container
    use traits_generic_factory_03_resolver, only: IResolver
    use traits_generic_factory_03_ifactory, only: IFactory
    implicit none
    private
    public :: Container

    ! A hand-written container: one factory per trait, keyed by the trait's
    ! qualified name.
    type, sealed, implements(IResolver) :: Container
        class(IFactory), allocatable :: client, logger, printer, writer
    contains
        procedure :: resolve
    end type Container

contains

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(*), allocatable :: obj
        character(:), allocatable :: key
        key = type_name{P}(qualified=.true.)
        if (key == "traits_generic_factory_03_traits::IClient") then
            obj = self%client%create(self)
        else if (key == "traits_generic_factory_03_traits::ILogger") then
            obj = self%logger%create(self)
        else if (key == "traits_generic_factory_03_traits::IPrinter") then
            obj = self%printer%create(self)
        else if (key == "traits_generic_factory_03_traits::IWriter") then
            obj = self%writer%create(self)
        else
            error stop "no registration"
        end if
        select type (obj)
        class is (P)
            res = obj
        class default
            error stop "the registered type does not implement the trait"
        end select
    end function resolve

end module traits_generic_factory_03_container

