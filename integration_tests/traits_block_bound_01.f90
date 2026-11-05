module traits_block_bound_01_m
    implicit none

    abstract interface :: ILength
        pure integer function length()
        end function length
    end interface

    type, abstract, implements(ILength) :: Base
    end type Base

    type, extends(Base), implements(ILength) :: Fixed
        integer :: n = 5
    contains
        procedure, nopass :: length => fixed_length
    end type Fixed

    type :: Holder
        class(Base), allocatable :: obj
    contains
        procedure :: check
    end type Holder

contains

    pure integer function fixed_length()
        fixed_length = 5
    end function fixed_length

    subroutine check(self)
        class(Holder), intent(in) :: self
        block
            real(8), dimension(self%obj%length()) :: tmp
            if (size(tmp) /= 5) error stop 1
        end block
    end subroutine check

end module traits_block_bound_01_m

program traits_block_bound_01
    use traits_block_bound_01_m
    implicit none
    type(Holder) :: h

    allocate(Fixed :: h%obj)
    call h%check()
    print '(a)', "trait message in a block declaration"
end program traits_block_bound_01
