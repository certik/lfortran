module continue_compilation_traits_sealed_receiver_generic_m
   type, sealed :: MyGeneric{T}
      type(T) :: number
   contains
      procedure :: output
   end type MyGeneric
contains
   subroutine output(self)
      class(MyGeneric{T}), intent(in) :: self
      print *, self%number
   end subroutine output
end module continue_compilation_traits_sealed_receiver_generic_m
