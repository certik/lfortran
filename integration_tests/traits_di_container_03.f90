! The dependency injection container of Sect. 4 of the traits extension
! proposal, Traits-for-Fortran Extensions/traits-di-extension.md, with the
! `IWriter` registration missing while `ILogger` is registered with
! DoubleLogger, whose initializer needs an IWriter. Resolving IClient
! resolves ILogger, whose factory calls `c%resolve{IWriter}()`; `retrieve`
! leaves `fact` unallocated, and the check that Sect. 4.5 adds to `resolve`
! stops with
!     ERROR STOP No registration available for IWriter!
! The modules are those of traits_di_container_01, with the same test
! instrumentation, marked "test:". The test is expected to fail.
! GFortran does not accept this LFortran extension.
! ---- ILoggerMod (Sect. 4.1, FortranDIContainer)
module ILoggerMod

   implicit none
   private

   public :: ILogger

   abstract interface :: ILogger
      subroutine log(self)
         type(itself), pass, intent(in) :: self
      end subroutine log
   end interface

end module ILoggerMod
! ---- IClientMod (Sect. 4.1, FortranDIContainer)
module IClientMod

   use ILoggerMod, only: ILogger

   implicit none
   private

   public :: IClient

   abstract interface, extends(ILogger) :: IClient
   end interface

end module IClientMod
! ---- IPrinterMod (FortranDIContainer)
module IPrinterMod

   implicit none
   private

   public :: IPrinter

   abstract interface :: IPrinter
      subroutine printout()
      end subroutine printout
   end interface

end module IPrinterMod
! ---- IWriterMod (FortranDIContainer)
module IWriterMod

   implicit none
   private

   public :: IWriter

   abstract interface :: IWriter
      subroutine writeout()
      end subroutine writeout
   end interface

end module IWriterMod
! ---- IResolverMod, IFactoryMod (Sect. 4.2)
module IResolverMod
   implicit none

   abstract interface :: IResolver
      function resolve{Trait :: P}(self) result(res)
         type(itself), pass, intent(in)  :: self
         class(P),           allocatable :: res
      end function resolve
   end interface

end module IResolverMod
module IFactoryMod
   use IResolverMod, only: IResolver
   implicit none

   !.. Swift: protocol IFactory { func create(_ c: any IResolver) -> Any }
   abstract interface :: IFactory
      function create(self, c) result(res)
         type(itself), pass, intent(in)  :: self
         class(IResolver),   intent(in)  :: c
         class(*),           allocatable :: res
      end function create
   end interface

end module IFactoryMod
! ---- InterfacesMod (Sect. 4.3)
module InterfacesMod
   implicit none

   !.. Swift: () -> U,  (T1) -> U,  (T1, T2) -> U
   abstract interface
      function ctor0{U}() result(res)
         type(U) :: res
      end function ctor0

      function ctor1{Trait :: T1, U}(a) result(res)
         class(T1), intent(in) :: a
         type(U)               :: res
      end function ctor1

      function ctor2{Trait :: T1, Trait :: T2, U}(a, b) result(res)
         class(T1), intent(in) :: a
         class(T2), intent(in) :: b
         type(U)               :: res
      end function ctor2
   end interface

end module InterfacesMod
! ---- FactoryMapMod (FortranDIContainer)
module FactoryMapMod

   use IFactoryMod, only: IFactory

   implicit none
   private

   public :: FactoryMap

   !.....................................................
   ! Hash map for class(IFactory) allocatables.
   !.....................................................

   integer, parameter :: bucket_count = 257

   type :: entry
      character(:),    allocatable :: key
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
      final     :: finalize_map
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


   integer function hash_key(key) result(index)
      character(*), intent(in) :: key
      integer :: i, h

      ! Small modulus keeps h*31 safely within default-integer range.
      h = 0
      do i = 1, len(key)
         h = modulo(31*h + iachar(key(i:i)), bucket_count)
      end do
      index = h + 1
   end function hash_key


   subroutine store(self,key,factory)
      class(FactoryMap), intent(inout) :: self
      character(*),      intent(in)    :: key
      class(IFactory),   intent(in)    :: factory

      type(entry), pointer :: p
      integer :: index

      call initialize(self)
      index = hash_key(key)
      p => self%buckets(index)%next

      ! Replace the procedure if this key is already present.
      do while (associated(p))
         if (p%key == key) then
            p%factory = factory
            return
         end if
         p => p%next
      end do

      ! Otherwise add a new entry at the head of the bucket chain.
      allocate(p)
      p%key = key
      p%factory = factory
      p%next => self%buckets(index)%next
      self%buckets(index)%next => p
   end subroutine store


   subroutine retrieve(self,key,factory)
      class(FactoryMap),            intent(in)  :: self
      character(*),                 intent(in)  :: key
      class(IFactory), allocatable, intent(out) :: factory

      type(entry), pointer :: p
      integer :: index

      if (.not. associated(self%buckets)) return

      index = hash_key(key)
      p => self%buckets(index)%next

      do while (associated(p))
         if (p%key == key) then
            factory = p%factory
            return
         end if
         p => p%next
      end do
   end subroutine retrieve


   subroutine clear(self)
      class(FactoryMap), intent(inout) :: self
      type(entry), pointer :: p, next_entry
      integer :: i

      if (.not. associated(self%buckets)) return

      do i = 1, size(self%buckets)
         p => self%buckets(i)%next
         do while (associated(p))
            next_entry => p%next
            deallocate(p)
            p => next_entry
         end do
         nullify(self%buckets(i)%next)
      end do

      deallocate(self%buckets)
   end subroutine clear


   subroutine finalize_map(self)
      type(FactoryMap), intent(inout) :: self
      call self%clear()
   end subroutine finalize_map

end module FactoryMapMod
! ---- FactoryMod (Sect. 4.4)
module FactoryMod
   use IFactoryMod,   only: IFactory
   use IResolverMod,  only: IResolver
   use InterfacesMod, only: ctor0, ctor1, ctor2
   implicit none
   private
   public :: Factory

   !.. the type-erasing decorator (Swift: struct Factory)
   type, sealed, implements(IFactory) :: Factory
      private
      class(IFactory), allocatable :: box
   contains
      initial   :: init0, init1, init2                   ! E8, E9
      procedure :: create
   end type Factory

   !.. helper types for type erasure, one per initializer arity
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
      type(Factory)       :: self
      self%box = Factory0(ctor)                          ! E8b
   end function init0

   function init1{Trait :: T1, U}(ctor) result(self)
      procedure(ctor1{T1,U}) :: ctor
      type(Factory)          :: self
      self%box = Factory1(ctor)
   end function init1

   function init2{Trait :: T1, Trait :: T2, U}(ctor) result(self)
      procedure(ctor2{T1,T2,U}) :: ctor
      type(Factory)             :: self
      self%box = Factory2(ctor)
   end function init2

   function create(self, c) result(res)
      type(Factory),    intent(in)  :: self
      class(IResolver), intent(in)  :: c
      class(*),         allocatable :: res
      res = self%box%create(c)
   end function create

   function create0(self, c) result(res)
      type(Factory0{U}), intent(in)  :: self
      class(IResolver),  intent(in)  :: c
      class(*),          allocatable :: res
      res = self%ctor()
   end function create0

   function create1(self, c) result(res)
      type(Factory1{T1,U}), intent(in)  :: self
      class(IResolver),     intent(in)  :: c
      class(*),             allocatable :: res
      res = self%ctor(c%resolve{T1}())                   ! E10
   end function create1

   function create2(self, c) result(res)
      type(Factory2{T1,T2,U}), intent(in)  :: self
      class(IResolver),        intent(in)  :: c
      class(*),                allocatable :: res
      res = self%ctor(c%resolve{T1}(), c%resolve{T2}())
   end function create2

end module FactoryMod
! ---- PrinterMod (FortranDIContainer), instrumented
module PrinterMod

   use IPrinterMod, only: IPrinter

   implicit none
   private

   public :: Printer
   public :: nprinted                                  ! test:

   integer :: nprinted = 0                             ! test: calls of printout

   type, implements(IPrinter) :: Printer
   contains
      procedure, nopass :: printout
   end type Printer

contains

   subroutine printout()
      write(*,*) "printing  ..."
      nprinted = nprinted + 1                          ! test:
   end subroutine printout

end module PrinterMod
! ---- WriterMod (FortranDIContainer), instrumented
module WriterMod

   use IWriterMod, only: IWriter

   implicit none
   private

   public :: Writer
   public :: nwritten                                  ! test:

   integer :: nwritten = 0                             ! test: calls of writeout

   type, implements(IWriter) :: Writer
   contains
      procedure, nopass :: writeout
   end type Writer

contains

   subroutine writeout()
      write(*,*) "writing  ..."
      nwritten = nwritten + 1                          ! test:
   end subroutine writeout

end module WriterMod
! ---- ClientMod (FortranDIContainer)
module ClientMod

   use IClientMod, only: IClient
   use ILoggerMod, only: ILogger

   implicit none
   private

   public :: Client

   type, implements(IClient) :: Client
      private
      class(ILogger), allocatable :: logger
   contains
      initial   :: init
      procedure :: log
   end type Client

contains

   function init(logger) result(self)
      class(ILogger), intent(in) :: logger
      type(Client)               :: self
      self%logger = logger
   end function init

   subroutine log(self)
      class(Client), intent(in) :: self
      write(*,*) "Calling logger from client:"
      call self%logger%log()
   end subroutine log

end module ClientMod
! ---- SingleLoggerMod (FortranDIContainer)
module SingleLoggerMod

   use ILoggerMod,  only: ILogger
   use IPrinterMod, only: IPrinter

   implicit none
   private

   public :: SingleLogger

   type, implements(ILogger) :: SingleLogger
      private
      class(IPrinter), allocatable :: printer
   contains
      initial   :: init
      procedure :: log
   end type SingleLogger

contains

   function init(printer) result(self)
      class(IPrinter), intent(in) :: printer
      type(SingleLogger)          :: self
      self%printer = printer
   end function init

   subroutine log(self)
      class(SingleLogger), intent(in) :: self
      write(*,*) "logging by "
      call self%printer%printout()
   end subroutine log

end module SingleLoggerMod
! ---- DoubleLoggerMod (Sect. 4.6)
module DoubleLoggerMod
   use ILoggerMod,  only: ILogger
   use IPrinterMod, only: IPrinter
   use IWriterMod,  only: IWriter
   implicit none
   private
   public :: DoubleLogger

   type, implements(ILogger) :: DoubleLogger
      private
      class(IPrinter), allocatable :: printer
      class(IWriter),  allocatable :: writer
   contains
      initial   :: init
      procedure :: log
   end type DoubleLogger

contains

   function init(printer, writer) result(self)
      class(IPrinter), intent(in) :: printer
      class(IWriter),  intent(in) :: writer
      type(DoubleLogger)          :: self
      self%printer = printer
      self%writer  = writer
   end function init

   subroutine log(self)
      class(DoubleLogger), intent(in) :: self
      write(*,*) "logging by "
      call self%printer%printout()
      call self%writer%writeout()
   end subroutine log

end module DoubleLoggerMod
! ---- ContainerMod (Sect. 4.5)
module ContainerMod
   use IResolverMod,  only: IResolver
   use IFactoryMod,   only: IFactory
   use InterfacesMod, only: ctor0, ctor1, ctor2
   use FactoryMapMod, only: FactoryMap
   use FactoryMod,    only: Factory
   implicit none
   private
   public :: Container

   !...........................................................
   ! Dependency injection container for traits.
   ! Employs trait parameters and overloading of generic methods.
   !...........................................................
   type, sealed, implements(IResolver) :: Container
      private
      type(FactoryMap) :: factories
   contains
      initial   :: init
      generic   :: register => register0, register1, register2
      procedure :: register0, register1, register2
      procedure :: resolve
   end type Container

contains

   function init() result(self)
      type(Container) :: self
   end function init

   !.. registration for initializers taking no arguments
   subroutine register0{Trait :: P, P :: U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor0{U})            :: ctor
      key := type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register0

   !.. registration for initializers taking one argument, of trait T1
   subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor1{T1,U})         :: ctor
      key := type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register1

   !.. registration for initializers taking two arguments, of traits T1 and T2
   subroutine register2{Trait :: P, Trait :: T1, Trait :: T2, P :: U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor2{T1,T2,U})      :: ctor
      key := type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register2

   !.. call the factory registered for trait P, passing it this
   !.. container, to resolve dependencies recursively
   function resolve{Trait :: P}(self) result(res)
      type(Container), intent(in)  :: self
      class(P),        allocatable :: res
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

end module ContainerMod
! ---- Main (Sect. 4.7, without the IWriter registration)
program main
   use IClientMod,      only: IClient
   use ILoggerMod,      only: ILogger
   use IPrinterMod,     only: IPrinter
   use IWriterMod,      only: IWriter
   use ContainerMod,    only: Container
   use ClientMod,       only: Client
   use SingleLoggerMod, only: SingleLogger
   use DoubleLoggerMod, only: DoubleLogger
   use PrinterMod,      only: Printer
   use WriterMod,       only: Writer
   implicit none

   type(Container), allocatable :: cont
   class(IClient),  allocatable :: cobj

   !.. get a dependency injection container
   cont = Container()

   !.. register a concrete type (initializer) with each trait, except IWriter
   call cont%register{IClient}(Client)
   call cont%register{ILogger}(DoubleLogger)
   call cont%register{IPrinter}(Printer)

   !.. recursively resolve the object graph, starting at the top trait:
   !.. stops in resolve{IWriter}
   cobj = cont%resolve{IClient}()

   ! test: not reached
   call cobj%log()
   print *, "unreachable: IWriter was resolved without a registration"

end program main
