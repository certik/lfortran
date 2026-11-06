module interfaces
   use, intrinsic :: iso_fortran_env, only: real64
   implicit none
   private
   public :: INumeric
   abstract interface :: INumeric
      real | real(real64)
   end interface
end module interfaces

module mytype_mod
   use interfaces, only: INumeric
   implicit none
   private
   public :: MyType
   type, sealed :: MyType{INumeric :: T}
      private
      type(T) :: number
   contains
      initial   :: init
      procedure :: output
      procedure :: get
   end type MyType
contains
   function init() result(self)
      type(MyType{T}) :: self
      self%number = T(2)
   end function init
   subroutine output(self)
      type(MyType{T}), intent(in) :: self
      print *, self%number
   end subroutine output

   function get(self) result(n)
      type(MyType{T}), intent(in) :: self
      type(T) :: n
      n = self%number
   end function get
end module mytype_mod

program test
   use, intrinsic :: iso_fortran_env, only: real64
   use mytype_mod
   type(MyType{real}) :: obj32
   type(MyType{real(real64)}) :: obj64
   obj32 = MyType{real}()
   obj64 = MyType{real(real64)}()
   call obj32%output()
   call obj64%output()
   if (obj32%get() /= 2.0) error stop
   if (obj64%get() /= 2.0_real64) error stop
end program test
