module continue_compilation_traits_sealed_receiver_m
   type, sealed :: MyType
      private
      real(8) :: number
   contains
      initial   :: init
      procedure :: output
   end type MyType
contains
   function init() result(self)
      type(MyType) :: self
      self%number = real(2,kind=8)
   end function init
   subroutine output(self)
      class(MyType), intent(in) :: self
      print *, self%number
   end subroutine output
end module continue_compilation_traits_sealed_receiver_m
