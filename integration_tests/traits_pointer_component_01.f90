module traits_pointer_component_01_mod
   implicit none

   abstract interface :: ISomeTrait
      subroutine notify(self)
         type(itself), pass, intent(inout) :: self
      end subroutine notify
   end interface

   type, sealed, implements(ISomeTrait) :: Counter
      integer :: count = 0
   contains
      procedure :: notify => counter_notify
   end type Counter

   type, sealed :: MyType
      class(ISomeTrait), pointer :: ptr => null()
   contains
      initial   :: init
   end type MyType

   type, sealed :: OwningHolder
      class(ISomeTrait), pointer :: ptr => null()
   contains
      final :: release_holder
   end type OwningHolder

contains

   subroutine counter_notify(self)
      type(Counter), intent(inout) :: self
      self%count = self%count + 1
   end subroutine counter_notify

   function init(ptr) result(self)
      class(ISomeTrait), target, intent(inout) :: ptr
      type(MyType)                             :: self
      self%ptr => ptr
   end function init

   subroutine release_holder(self)
      type(OwningHolder), intent(inout) :: self
      if (associated(self%ptr)) then
         deallocate(self%ptr)
      end if
   end subroutine release_holder

end module traits_pointer_component_01_mod

program traits_pointer_component_01
   use traits_pointer_component_01_mod
   implicit none

   type(Counter), target :: c
   type(MyType) :: m
   type(OwningHolder) :: h

   if (associated(m%ptr)) error stop 1
   m = MyType(c)
   if (.not. associated(m%ptr)) error stop 2
   call m%ptr%notify()
   call m%ptr%notify()
   if (c%count /= 2) error stop 3
   nullify(m%ptr)
   if (associated(m%ptr)) error stop 4

   if (associated(h%ptr)) error stop 5
   allocate(h%ptr, source=Counter(10))
   if (.not. associated(h%ptr)) error stop 6
   call h%ptr%notify()
   select type (x => h%ptr)
   type is (Counter)
      if (x%count /= 11) error stop 7
   class default
      error stop 8
   end select
   deallocate(h%ptr)
   if (associated(h%ptr)) error stop 9

   allocate(h%ptr, source=Counter(20))
   call h%ptr%notify()
end program traits_pointer_component_01
