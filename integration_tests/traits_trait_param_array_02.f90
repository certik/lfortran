! The elements of an array of trait objects of a trait parameter share one
! dynamic type (#18485, TD-46): appending a Circle to `Vector{IShape}` of
! squares assigns a square to an element of the reallocated array of
! circles, which stops the program with an error naming both dynamic types
! (checked by its `run` reference test in tests/tests.toml).
! GFortran does not accept this LFortran extension.
module traits_trait_param_array_02_mod
    implicit none
    private
    public :: IShape, Square, Circle, Vector

    abstract interface :: IShape
        integer function area(self)
            type(itself), intent(in), pass :: self
        end function area
    end interface IShape

    type, implements(IShape) :: Square
        integer :: side = 1
    contains
        procedure :: area => square_area
    end type Square

    type, implements(IShape) :: Circle
        integer :: r = 1
    contains
        procedure :: area => circle_area
    end type Circle

    type, sealed :: Vector{Trait :: U}
        class(U), allocatable :: elements(:)
    contains
        procedure, pass :: append
    end type Vector

contains

    integer function square_area(self)
        class(Square), intent(in) :: self
        square_area = self%side**2
    end function square_area

    integer function circle_area(self)
        class(Circle), intent(in) :: self
        circle_area = 3 * self%r**2
    end function circle_area

    subroutine append(self, item)
        type(Vector{U}), intent(inout) :: self
        class(U), intent(in) :: item
        class(U), allocatable :: old(:)
        integer :: n, i
        if (.not. allocated(self%elements)) then
            allocate(self%elements(1), source=item)
            return
        end if
        n = size(self%elements)
        allocate(old(n), source=self%elements(1))
        deallocate(self%elements)
        allocate(self%elements(n + 1), source=item)
        do i = 1, n
            self%elements(i) = old(i)
        end do
    end subroutine append
end module traits_trait_param_array_02_mod

program traits_trait_param_array_02
    use traits_trait_param_array_02_mod
    implicit none
    type(Vector{IShape}) :: shapes
    call shapes%append(Square(2))
    if (shapes%elements(1)%area() /= 4) error stop 1
    call shapes%append(Circle(1))
    print *, "not reached"
end program traits_trait_param_array_02
