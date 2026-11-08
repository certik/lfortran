module mytype_mod
   implicit none
   private
   public :: MyType
   type, sealed :: MyType{real | real(8) | complex :: T}
      private
      type(T) :: number
   end type MyType
   implements :: MyType{real | real(8) | complex :: T}
      initial   :: init
      procedure :: get
   end implements
contains
   function init() result(self)
      type(MyType{T}) :: self
      self%number = T(2)
   end function init
   function get(self) result(n)
      type(MyType{T}), intent(in) :: self
      type(T) :: n
      n = self%number
   end function get
end module mytype_mod

program traits_implements_generic_type_02
   use mytype_mod, only: MyType
   implicit none
   tr4 := MyType{real}()
   tr8 := MyType{real(8)}()
   tc8 := MyType{complex}()
   if (tr4%get() /= 2.0) error stop
   if (tr8%get() /= 2.0d0) error stop
   if (tc8%get() /= (2.0, 0.0)) error stop
end program traits_implements_generic_type_02
