! Issue #18927: DI container using pointer components for trait objects
! (`class(T), pointer :: value => null()`, `class(IFactory), pointer :: box`,
! `class(ILogger), pointer :: logger`, `class(IPrinter), pointer :: printer`,
! `class(IWriter), pointer :: writer`) with `allocate(..., source=...)` and
! `final` procedures on `Entry{Trait::T}` and `HashMap{Trait::T}`.

module traits_pointer_component_02_interfaces
   implicit none

   abstract interface :: IPrinter
      subroutine printout(self, count)
         type(itself), pass, intent(in) :: self
         integer, intent(inout) :: count
      end subroutine printout
   end interface

   abstract interface :: IWriter
      subroutine writeout(self, count)
         type(itself), pass, intent(in) :: self
         integer, intent(inout) :: count
      end subroutine writeout
   end interface

   abstract interface :: ILogger
      subroutine log(self, count)
         type(itself), pass, intent(in) :: self
         integer, intent(inout) :: count
      end subroutine log
   end interface

   abstract interface :: IClient
      subroutine log(self, count)
         type(itself), pass, intent(in) :: self
         integer, intent(inout) :: count
      end subroutine log
   end interface

   abstract interface :: IResolver
      function resolve{Trait::P}(self) result(res)
         type(itself), pass, intent(in)  :: self
         class(P),           allocatable :: res
      end function resolve
   end interface

   abstract interface :: IFactory
      function create(self, c) result(res)
         type(itself),     pass, intent(in)  :: self
         class(IResolver),       intent(in)  :: c
         class(*),               allocatable :: res
      end function create
   end interface

   abstract interface
      function ctor0{U}() result(res)
         type(U) :: res
      end function ctor0

      function ctor1{Trait::T1, U}(a) result(res)
         class(T1), intent(in) :: a
         type(U)               :: res
      end function ctor1

      function ctor2{Trait::T1, Trait::T2, U}(a, b) result(res)
         class(T1), intent(in) :: a
         class(T2), intent(in) :: b
         type(U)               :: res
      end function ctor2
   end interface

   abstract interface, extends(IResolver) :: IContainer
      subroutine register{Trait::P, P::U}(self, ctor)
         type(itself), pass, intent(inout) :: self
         procedure(ctor0{U})               :: ctor
      end subroutine register

      subroutine register{Trait::P, Trait::T1, P::U}(self, ctor)
         type(itself), pass, intent(inout) :: self
         procedure(ctor1{T1,U})            :: ctor
      end subroutine register

      subroutine register{Trait::P, Trait::T1, Trait::T2, P::U}(self, ctor)
         type(itself), pass, intent(inout) :: self
         procedure(ctor2{T1,T2,U})         :: ctor
      end subroutine register
   end interface

end module traits_pointer_component_02_interfaces

module traits_pointer_component_02_hashmap
   implicit none
   private

   public :: HashMap, entry_finalized_count

   integer :: entry_finalized_count = 0
   integer, parameter :: bucket_count = 31

   type, sealed :: Entry{Trait::T}
      character(:), allocatable :: key
      class(T),     pointer     :: value => null()
      type(Entry{T}), pointer   :: next => null()
   contains
      final :: finalize_entry
   end type Entry

   type, sealed :: HashMap{Trait::T}
      private
      type(Entry{T}), pointer :: buckets(:) => null()
   contains
      procedure :: store
      procedure :: retrieve
      procedure :: clear
      final     :: finalize_map
   end type HashMap

contains

   subroutine initialize(self)
      type(HashMap{T}), intent(inout) :: self
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
      h = 0
      do i = 1, len(key)
         h = modulo(31*h + iachar(key(i:i)), bucket_count)
      end do
      index = h + 1
   end function hash_key

   subroutine store(self, key, value)
      type(HashMap{T}), intent(inout) :: self
      character(*),     intent(in)    :: key
      class(T),         intent(in)    :: value
      type(Entry{T}), pointer :: p
      integer :: index

      call initialize(self)
      index = hash_key(key)
      p => self%buckets(index)%next
      do while (associated(p))
         if (p%key == key) then
            if (associated(p%value)) deallocate(p%value)
            allocate(p%value, source=value)
            return
         end if
         p => p%next
      end do
      allocate(p)
      p%key = key
      allocate(p%value, source=value)
      p%next => self%buckets(index)%next
      self%buckets(index)%next => p
   end subroutine store

   subroutine retrieve(self, key, value)
      type(HashMap{T}),      intent(in)  :: self
      character(*),          intent(in)  :: key
      class(T), allocatable, intent(out) :: value
      type(Entry{T}), pointer :: p
      integer :: index

      if (.not. associated(self%buckets)) return
      index = hash_key(key)
      p => self%buckets(index)%next
      do while (associated(p))
         if (p%key == key) then
            if (associated(p%value)) value = p%value
            return
         end if
         p => p%next
      end do
   end subroutine retrieve

   subroutine clear(self)
      type(HashMap{T}), intent(inout) :: self
      type(Entry{T}),   pointer       :: p, next_entry
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

   subroutine finalize_entry(self)
      type(Entry{T}), intent(inout) :: self
      if (associated(self%value)) then
         entry_finalized_count = entry_finalized_count + 1
         deallocate(self%value)
      end if
   end subroutine finalize_entry

   subroutine finalize_map(self)
      type(HashMap{T}), intent(inout) :: self
      call self%clear()
   end subroutine finalize_map

end module traits_pointer_component_02_hashmap

module traits_pointer_component_02_container
   use traits_pointer_component_02_interfaces
   use traits_pointer_component_02_hashmap, only: HashMap
   implicit none
   private

   public :: Container

   type, sealed, implements(IFactory) :: Factory
      private
      class(IFactory), pointer :: box => null()
   contains
      initial   :: init0, init1, init2
      procedure :: create
   end type Factory

   type, sealed, implements(IFactory) :: Factory0{U}
      private
      procedure(ctor0{U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create0
   end type Factory0

   type, sealed, implements(IFactory) :: Factory1{Trait::T1, U}
      private
      procedure(ctor1{T1,U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create1
   end type Factory1

   type, sealed, implements(IFactory) :: Factory2{Trait::T1, Trait::T2, U}
      private
      procedure(ctor2{T1,T2,U}), pointer, nopass :: ctor => null()
   contains
      procedure :: create => create2
   end type Factory2

   type, sealed, implements(IContainer) :: Container
      private
      type(HashMap{IFactory}) :: factories
   contains
      initial   :: init_container
      generic   :: register => register0, register1, register2
      procedure :: register0, register1, register2
      procedure :: resolve
   end type Container

contains

   function init0{U}(ctor) result(self)
      procedure(ctor0{U}) :: ctor
      type(Factory)       :: self
      allocate(self%box, source=Factory0(ctor))
   end function init0

   function init1{Trait::T1, U}(ctor) result(self)
      procedure(ctor1{T1,U}) :: ctor
      type(Factory)          :: self
      allocate(self%box, source=Factory1(ctor))
   end function init1

   function init2{Trait::T1, Trait::T2, U}(ctor) result(self)
      procedure(ctor2{T1,T2,U}) :: ctor
      type(Factory)             :: self
      allocate(self%box, source=Factory2(ctor))
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
      res = self%ctor(c%resolve{T1}())
   end function create1

   function create2(self, c) result(res)
      type(Factory2{T1,T2,U}), intent(in)  :: self
      class(IResolver),        intent(in)  :: c
      class(*),                allocatable :: res
      res = self%ctor(c%resolve{T1}(), c%resolve{T2}())
   end function create2

   function init_container() result(self)
      type(Container) :: self
   end function init_container

   subroutine register0{Trait::P, P::U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor0{U})            :: ctor
      character(:), allocatable      :: key
      key = type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register0

   subroutine register1{Trait::P, Trait::T1, P::U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor1{T1,U})         :: ctor
      character(:), allocatable      :: key
      key = type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register1

   subroutine register2{Trait::P, Trait::T1, Trait::T2, P::U}(self, ctor)
      type(Container), intent(inout) :: self
      procedure(ctor2{T1,T2,U})      :: ctor
      character(:), allocatable      :: key
      key = type_name{P}(qualified=.true.)
      call self%factories%store(key, Factory(ctor))
   end subroutine register2

   function resolve{Trait::P}(self) result(res)
      type(Container), intent(in)  :: self
      class(P),        allocatable :: res
      class(IFactory), allocatable :: fact
      character(:),    allocatable :: key
      key = type_name{P}(qualified=.true.)
      call self%factories%retrieve(key, fact)
      if (.not. allocated(fact)) error stop 10
      select type (obj => fact%create(self))
      class is (P)
         res = obj
      class default
         error stop 11
      end select
   end function resolve

end module traits_pointer_component_02_container

module traits_pointer_component_02_impls
   use traits_pointer_component_02_interfaces
   implicit none

   type, sealed, implements(IPrinter) :: Printer
   contains
      procedure :: printout => printer_printout
   end type Printer

   type, sealed, implements(IWriter) :: Writer
   contains
      procedure :: writeout => writer_writeout
   end type Writer

   type, sealed, implements(ILogger) :: SingleLogger
      class(IPrinter), pointer :: printer => null()
   contains
      initial   :: init_single
      procedure :: log => single_log
   end type SingleLogger

   type, sealed, implements(ILogger) :: DoubleLogger
      class(IPrinter), pointer :: printer => null()
      class(IWriter),  pointer :: writer  => null()
   contains
      initial   :: init_double
      procedure :: log => double_log
   end type DoubleLogger

   type, sealed, implements(IClient) :: Client
      class(ILogger), pointer :: logger => null()
   contains
      initial   :: init_client
      procedure :: log => client_log
   end type Client

contains

   subroutine printer_printout(self, count)
      type(Printer), intent(in) :: self
      integer, intent(inout) :: count
      count = count + 1
   end subroutine printer_printout

   subroutine writer_writeout(self, count)
      type(Writer), intent(in) :: self
      integer, intent(inout) :: count
      count = count + 10
   end subroutine writer_writeout

   function init_single(printer) result(self)
      class(IPrinter), intent(in) :: printer
      type(SingleLogger)          :: self
      allocate(self%printer, source=printer)
   end function init_single

   subroutine single_log(self, count)
      type(SingleLogger), intent(in) :: self
      integer, intent(inout) :: count
      count = count + 200
      call self%printer%printout(count)
   end subroutine single_log

   function init_double(printer, writer) result(self)
      class(IPrinter), intent(in) :: printer
      class(IWriter),  intent(in) :: writer
      type(DoubleLogger)          :: self
      allocate(self%printer, source=printer)
      allocate(self%writer,  source=writer)
   end function init_double

   subroutine double_log(self, count)
      type(DoubleLogger), intent(in) :: self
      integer, intent(inout) :: count
      count = count + 100
      call self%printer%printout(count)
      call self%writer%writeout(count)
   end subroutine double_log

   function init_client(logger) result(self)
      class(ILogger), intent(in) :: logger
      type(Client)               :: self
      allocate(self%logger, source=logger)
   end function init_client

   subroutine client_log(self, count)
      type(Client), intent(in) :: self
      integer, intent(inout) :: count
      count = count + 1000
      call self%logger%log(count)
   end subroutine client_log

end module traits_pointer_component_02_impls

program traits_pointer_component_02
   use traits_pointer_component_02_interfaces
   use traits_pointer_component_02_hashmap, only: entry_finalized_count
   use traits_pointer_component_02_container, only: Container
   use traits_pointer_component_02_impls
   implicit none

   integer :: total

   block
      class(IContainer), allocatable :: cont
      class(IClient),    allocatable :: cobj

      cont = Container()
      call cont%register{IClient}(Client)
      call cont%register{ILogger}(DoubleLogger)
      call cont%register{IPrinter}(Printer)
      call cont%register{IWriter}(Writer)

      cobj = cont%resolve{IClient}()
      total = 0
      call cobj%log(total)
      if (total /= 1111) error stop 1

      ! Overwrite ILogger registration with SingleLogger
      call cont%register{ILogger}(SingleLogger)
      cobj = cont%resolve{IClient}()
      total = 0
      call cobj%log(total)
      if (total /= 1201) error stop 2
   end block

   if (entry_finalized_count /= 4) error stop 3
end program traits_pointer_component_02
