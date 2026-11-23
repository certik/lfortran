! The MRE of https://github.com/lfortran/lfortran/issues/18485, verbatim:
! an array of trait objects of the trait parameter U as a component of
! a generic type, used with a concrete trait.
module trait_vector

   type :: Vector{trait::U}
      class(U), allocatable :: elements(:)
   end type Vector

end module trait_vector

module traits_trait_param_array_03_shapes_m
   implicit none
   abstract interface :: IShape
      function area(self) result(a)
         type(itself), pass, intent(in) :: self
         integer :: a
      end function area
   end interface IShape

   type, implements(IShape) :: Square
      integer :: side = 0
   contains
      procedure :: area => square_area
   end type Square
contains
   function square_area(self) result(a)
      class(Square), intent(in) :: self
      integer :: a
      a = self%side * self%side
   end function square_area
end module traits_trait_param_array_03_shapes_m

program traits_trait_param_array_03
   use trait_vector
   use traits_trait_param_array_03_shapes_m
   implicit none
   type(Vector{IShape}) :: v
   integer :: i, total
   allocate(v%elements(3), source=Square(2))
   total = 0
   do i = 1, size(v%elements)
      total = total + v%elements(i)%area()
   end do
   if (total /= 12) error stop 1
   print *, total
end program traits_trait_param_array_03
