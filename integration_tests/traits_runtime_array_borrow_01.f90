! A whole nonpolymorphic array borrowed as a runtime trait array (TD-46) by a
! function called in an expression is passed in place, without a temporary
! copy, as a section is: the reference in a comparison, in an arithmetic
! expression and as an actual argument, of a fixed-size, an allocatable and
! a component array.
module traits_runtime_array_borrow_01_m
    implicit none
    abstract interface :: IShape
        integer function area(self)
            type(itself), pass, intent(in) :: self
        end function area
    end interface

    type, implements(IShape) :: Square
        integer :: side = 2
    contains
        procedure :: area => square_area
    end type Square

    type :: Holder
        type(Square) :: items(3)
    end type Holder

contains

    integer function square_area(self)
        class(Square), intent(in) :: self
        square_area = self%side**2
    end function square_area

    integer function total(a) result(s)
        class(IShape), intent(in) :: a(:)
        integer :: i
        s = 0
        do i = 1, size(a)
            s = s + a(i)%area()
        end do
    end function total
end module traits_runtime_array_borrow_01_m

program traits_runtime_array_borrow_01
    use traits_runtime_array_borrow_01_m
    implicit none
    type(Square) :: plain(4)
    type(Square), allocatable :: grown(:)
    type(Holder) :: h
    plain(2)%side = 3
    allocate(grown(2))
    if (total(plain) /= 4 + 9 + 4 + 4) error stop 1
    if (2 * total(grown) + 1 /= 17) error stop 2
    if (total(h%items) /= 12) error stop 3
    if (max(total(plain), total(grown)) /= 21) error stop 4
    print *, "ok"
end program traits_runtime_array_borrow_01
