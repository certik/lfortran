! The MRE of https://github.com/lfortran/lfortran/issues/18554, verbatim:
! Vector{trait::U} has a component that is an array of another generic type
! instantiated on the same trait parameter, Entry{U}.
module trait_vector

   type :: Entry{trait::U}
      class(U), allocatable :: item
   end type Entry

   type :: Vector{trait::U}
      type(Entry{U}), allocatable :: elements(:)
   end type Vector

end module trait_vector

module traits_trait_param_array_04_shapes_m
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
end module traits_trait_param_array_04_shapes_m

program traits_trait_param_array_04
   use trait_vector
   use traits_trait_param_array_04_shapes_m
   implicit none
   type(Vector{IShape}) :: v
   allocate(v%elements(1))
   allocate(v%elements(1)%item, source=Square(3))
   if (v%elements(1)%item%area() /= 9) error stop 1
   print *, v%elements(1)%item%area()
end program traits_trait_param_array_04
