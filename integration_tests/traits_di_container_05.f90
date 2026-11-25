! Full Fortran translation of the Swift `noclosure` DIContainer pattern
! (https://github.com/difference-scheme/DIContainer/tree/noclosure):
! `IContainer` extends `IResolver` with overloaded generic `register` messages
! for 0-, 1-, and 2-argument constructors; `ISetup` (`CommonSetup`,
! `DoubleLoggingSetup`, `SingleLoggingSetup`) registers `Client`, `Printer`,
! `Writer`, `DoubleLogger`, and `SingleLogger` through `class(IContainer)`;
! `Container` erases them into `Factory0{U}`, `Factory1{Trait::T1, U}`, and
! `Factory2{Trait::T1, Trait::T2, U}` boxed in `Factory`, and `c%resolve{IClient}()`
! recursively resolves the full object graph through `class(IContainer)`.
! GFortran does not accept this LFortran extension.
module traits_di_container_05_iprinter
    implicit none
    abstract interface :: IPrinter
        subroutine printout(self)
            type(itself), pass, intent(in) :: self
        end subroutine printout
    end interface
end module traits_di_container_05_iprinter

module traits_di_container_05_iwriter
    implicit none
    abstract interface :: IWriter
        subroutine writeout(self)
            type(itself), pass, intent(in) :: self
        end subroutine writeout
    end interface
end module traits_di_container_05_iwriter

module traits_di_container_05_ilogger
    implicit none
    abstract interface :: ILogger
        subroutine log(self)
            type(itself), pass, intent(in) :: self
        end subroutine log
    end interface
end module traits_di_container_05_ilogger

module traits_di_container_05_iclient
    use traits_di_container_05_ilogger, only: ILogger
    implicit none
    abstract interface, extends(ILogger) :: IClient
    end interface
end module traits_di_container_05_iclient

module traits_di_container_05_iresolver
    implicit none
    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), pass, intent(in) :: self
            class(P), allocatable :: res
        end function resolve
    end interface
end module traits_di_container_05_iresolver

module traits_di_container_05_ifactory
    use traits_di_container_05_iresolver, only: IResolver
    implicit none
    abstract interface :: IFactory
        function create(self, c) result(res)
            type(itself), pass, intent(in) :: self
            class(IResolver), intent(in) :: c
            class(*), allocatable :: res
        end function create
    end interface
end module traits_di_container_05_ifactory

module traits_di_container_05_interfaces
    implicit none
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
end module traits_di_container_05_interfaces

module traits_di_container_05_icontainer
    use traits_di_container_05_iresolver, only: IResolver
    use traits_di_container_05_interfaces, only: ctor0, ctor1, ctor2
    implicit none
    abstract interface, extends(IResolver) :: IContainer
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1, U}) :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor2{T1, T2, U}) :: ctor
        end subroutine register
    end interface
end module traits_di_container_05_icontainer

module traits_di_container_05_isetup
    use traits_di_container_05_icontainer, only: IContainer
    implicit none
    abstract interface :: ISetup
        subroutine registration(self, c)
            type(itself), pass, intent(in) :: self
            class(IContainer), intent(inout) :: c
        end subroutine registration
    end interface
end module traits_di_container_05_isetup

module traits_di_container_05_factory_map
    use traits_di_container_05_ifactory, only: IFactory
    implicit none
    private
    public :: FactoryMap

    integer, parameter :: bucket_count = 31

    type :: entry
        character(:), allocatable :: key
        class(IFactory), allocatable :: factory
        type(entry), pointer :: next => null()
    end type entry

    type :: FactoryMap
        private
        type(entry), pointer :: buckets(:) => null()
    contains
        procedure :: store
        procedure :: retrieve
        procedure :: clear
        final :: finalize_map
    end type FactoryMap
contains
    subroutine initialize(self)
        class(FactoryMap), intent(inout) :: self
        integer :: i
        if (.not. associated(self%buckets)) then
            allocate(self%buckets(bucket_count))
            do i = 1, bucket_count
                nullify(self%buckets(i)%next)
            end do
        end if
    end subroutine initialize

    integer function hash_key(key) result(idx)
        character(*), intent(in) :: key
        integer :: i, h
        h = 0
        do i = 1, len(key)
            h = mod(h * 31 + iachar(key(i:i)), bucket_count)
        end do
        idx = h + 1
    end function hash_key

    subroutine store(self, key, factory)
        class(FactoryMap), intent(inout) :: self
        character(*), intent(in) :: key
        class(IFactory), intent(in) :: factory
        type(entry), pointer :: cur, node
        integer :: b
        call initialize(self)
        b = hash_key(key)
        cur => self%buckets(b)%next
        do while (associated(cur))
            if (cur%key == key) then
                cur%factory = factory
                return
            end if
            cur => cur%next
        end do
        allocate(node)
        node%key = key
        node%factory = factory
        node%next => self%buckets(b)%next
        self%buckets(b)%next => node
    end subroutine store

    subroutine retrieve(self, key, factory)
        class(FactoryMap), intent(in) :: self
        character(*), intent(in) :: key
        class(IFactory), allocatable, intent(out) :: factory
        type(entry), pointer :: cur
        integer :: b
        if (.not. associated(self%buckets)) return
        b = hash_key(key)
        cur => self%buckets(b)%next
        do while (associated(cur))
            if (cur%key == key) then
                factory = cur%factory
                return
            end if
            cur => cur%next
        end do
    end subroutine retrieve

    subroutine clear(self)
        class(FactoryMap), intent(inout) :: self
        type(entry), pointer :: cur, nxt
        integer :: i
        if (.not. associated(self%buckets)) return
        do i = 1, bucket_count
            cur => self%buckets(i)%next
            do while (associated(cur))
                nxt => cur%next
                deallocate(cur)
                cur => nxt
            end do
            nullify(self%buckets(i)%next)
        end do
        deallocate(self%buckets)
    end subroutine clear

    subroutine finalize_map(self)
        type(FactoryMap), intent(inout) :: self
        call self%clear()
    end subroutine finalize_map
end module traits_di_container_05_factory_map

module traits_di_container_05_factory
    use traits_di_container_05_ifactory, only: IFactory
    use traits_di_container_05_iresolver, only: IResolver
    use traits_di_container_05_interfaces, only: ctor0, ctor1, ctor2
    implicit none
    private
    public :: Factory

    type, sealed, implements(IFactory) :: Factory
        private
        class(IFactory), allocatable :: box
    contains
        initial :: init0, init1, init2
        procedure :: create
    end type Factory

    type, sealed, implements(IFactory) :: Factory0{U}
        private
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    contains
        procedure :: create => create0
    end type Factory0

    type, sealed, implements(IFactory) :: Factory1{Trait :: T1, U}
        private
        procedure(ctor1{T1, U}), pointer, nopass :: ctor => null()
    contains
        procedure :: create => create1
    end type Factory1

    type, sealed, implements(IFactory) :: Factory2{Trait :: T1, Trait :: T2, U}
        private
        procedure(ctor2{T1, T2, U}), pointer, nopass :: ctor => null()
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
        procedure(ctor1{T1, U}) :: ctor
        type(Factory) :: self
        self%box = Factory1(ctor)
    end function init1

    function init2{Trait :: T1, Trait :: T2, U}(ctor) result(self)
        procedure(ctor2{T1, T2, U}) :: ctor
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
        type(Factory1{T1, U}), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%ctor(c%resolve{T1}())
    end function create1

    function create2(self, c) result(res)
        type(Factory2{T1, T2, U}), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%ctor(c%resolve{T1}(), c%resolve{T2}())
    end function create2
end module traits_di_container_05_factory

module traits_di_container_05_container
    use traits_di_container_05_icontainer, only: IContainer
    use traits_di_container_05_ifactory, only: IFactory
    use traits_di_container_05_interfaces, only: ctor0, ctor1, ctor2
    use traits_di_container_05_factory_map, only: FactoryMap
    use traits_di_container_05_factory, only: Factory
    implicit none
    private
    public :: Container

    type, sealed, implements(IContainer) :: Container
        private
        type(FactoryMap) :: factories
    contains
        initial :: init
        generic :: register => register0, register1, register2
        procedure :: register0, register1, register2
        procedure :: resolve
    end type Container
contains
    function init() result(self)
        type(Container) :: self
    end function init

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        key := type_name{P}(qualified=.true.)
        call self%factories%store(key, Factory(ctor))
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor1{T1, U}) :: ctor
        key := type_name{P}(qualified=.true.)
        call self%factories%store(key, Factory(ctor))
    end subroutine register1

    subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor2{T1, T2, U}) :: ctor
        key := type_name{P}(qualified=.true.)
        call self%factories%store(key, Factory(ctor))
    end subroutine register2

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(IFactory), allocatable :: fact
        key := type_name{P}(qualified=.true.)
        call self%factories%retrieve(key, fact)
        if (.not. allocated(fact)) &
            error stop "No registration available for " // type_name{P}() // "!"
        select type (obj => fact%create(self))
        class is (P)
            res = obj
        class default
            error stop "No registration available for " // type_name{P}() // "!"
        end select
    end function resolve
end module traits_di_container_05_container

module traits_di_container_05_impls
    use traits_di_container_05_iprinter, only: IPrinter
    use traits_di_container_05_iwriter, only: IWriter
    use traits_di_container_05_ilogger, only: ILogger
    use traits_di_container_05_iclient, only: IClient
    implicit none
    private
    public :: Printer, Writer, SingleLogger, DoubleLogger, Client
    public :: nprinted, nwritten

    integer :: nprinted = 0
    integer :: nwritten = 0

    type, implements(IPrinter) :: Printer
    contains
        procedure :: printout
    end type Printer

    type, implements(IWriter) :: Writer
    contains
        procedure :: writeout
    end type Writer

    type, implements(ILogger) :: SingleLogger
        private
        class(IPrinter), allocatable :: printer
    contains
        initial :: init_single
        procedure :: log => log_single
    end type SingleLogger

    type, implements(ILogger) :: DoubleLogger
        private
        class(IPrinter), allocatable :: printer
        class(IWriter), allocatable :: writer
    contains
        initial :: init_double
        procedure :: log => log_double
    end type DoubleLogger

    type, implements(IClient) :: Client
        private
        class(ILogger), allocatable :: logger
    contains
        initial :: init_client
        procedure :: log => log_client
    end type Client
contains
    subroutine printout(self)
        class(Printer), intent(in) :: self
        nprinted = nprinted + 1
    end subroutine printout

    subroutine writeout(self)
        class(Writer), intent(in) :: self
        nwritten = nwritten + 1
    end subroutine writeout

    function init_single(printer) result(self)
        class(IPrinter), intent(in) :: printer
        type(SingleLogger) :: self
        self%printer = printer
    end function init_single

    subroutine log_single(self)
        class(SingleLogger), intent(in) :: self
        call self%printer%printout()
    end subroutine log_single

    function init_double(printer, writer) result(self)
        class(IPrinter), intent(in) :: printer
        class(IWriter), intent(in) :: writer
        type(DoubleLogger) :: self
        self%printer = printer
        self%writer = writer
    end function init_double

    subroutine log_double(self)
        class(DoubleLogger), intent(in) :: self
        call self%printer%printout()
        call self%writer%writeout()
    end subroutine log_double

    function init_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%logger = logger
    end function init_client

    subroutine log_client(self)
        class(Client), intent(in) :: self
        call self%logger%log()
    end subroutine log_client
end module traits_di_container_05_impls

module traits_di_container_05_setups
    use traits_di_container_05_isetup, only: ISetup
    use traits_di_container_05_icontainer, only: IContainer
    use traits_di_container_05_iclient, only: IClient
    use traits_di_container_05_ilogger, only: ILogger
    use traits_di_container_05_iprinter, only: IPrinter
    use traits_di_container_05_iwriter, only: IWriter
    use traits_di_container_05_impls, only: Client, Printer, Writer, SingleLogger, DoubleLogger
    implicit none
    private
    public :: CommonSetup, SingleLoggingSetup, DoubleLoggingSetup

    type, sealed, implements(ISetup) :: CommonSetup
    contains
        procedure :: registration => common_registration
    end type CommonSetup

    type, sealed, implements(ISetup) :: SingleLoggingSetup
    contains
        procedure :: registration => single_registration
    end type SingleLoggingSetup

    type, sealed, implements(ISetup) :: DoubleLoggingSetup
    contains
        procedure :: registration => double_registration
    end type DoubleLoggingSetup
contains
    subroutine common_registration(self, c)
        type(CommonSetup), intent(in) :: self
        class(IContainer), intent(inout) :: c
        call c%register{IClient}(Client)
        call c%register{IPrinter}(Printer)
        call c%register{IWriter}(Writer)
    end subroutine common_registration

    subroutine single_registration(self, c)
        type(SingleLoggingSetup), intent(in) :: self
        class(IContainer), intent(inout) :: c
        call c%register{ILogger}(SingleLogger)
    end subroutine single_registration

    subroutine double_registration(self, c)
        type(DoubleLoggingSetup), intent(in) :: self
        class(IContainer), intent(inout) :: c
        call c%register{ILogger}(DoubleLogger)
    end subroutine double_registration
end module traits_di_container_05_setups

program traits_di_container_05
    use traits_di_container_05_iclient, only: IClient
    use traits_di_container_05_isetup, only: ISetup
    use traits_di_container_05_icontainer, only: IContainer
    use traits_di_container_05_container, only: Container
    use traits_di_container_05_setups, only: CommonSetup, SingleLoggingSetup, DoubleLoggingSetup
    use traits_di_container_05_impls, only: nprinted, nwritten
    implicit none

    class(IContainer), allocatable :: c
    class(ISetup), allocatable :: common_setup, logging_setup
    class(IClient), allocatable :: cli

    ! Double logging setup through class(IContainer) and class(ISetup)
    c = Container()
    common_setup = CommonSetup()
    logging_setup = DoubleLoggingSetup()
    call common_setup%registration(c)
    call logging_setup%registration(c)
    cli = c%resolve{IClient}()
    call cli%log()
    if (nprinted /= 1 .or. nwritten /= 1) error stop 1

    ! Switch to single logging setup on the same container
    logging_setup = SingleLoggingSetup()
    call logging_setup%registration(c)
    cli = c%resolve{IClient}()
    call cli%log()
    if (nprinted /= 2 .or. nwritten /= 1) error stop 2

    deallocate(c)
end program traits_di_container_05
