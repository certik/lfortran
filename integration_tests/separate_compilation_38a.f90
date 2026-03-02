module separate_compilation_38a
    implicit none
    private
    integer, parameter :: dp = kind(1.0d0)
    abstract interface
        subroutine vector_sub(x, y)
            import :: dp
            real(dp), intent(in)  :: x(:)
            real(dp), intent(inout) :: y(:)
        end subroutine
    end interface
    type, public :: op_type
        procedure(vector_sub), nopass, pointer :: matvec => null()
    end type
    type, public :: wksp_type
        real(dp), allocatable :: tmp(:,:)
    end type
    interface
        module subroutine kernel(A, wksp)
            class(op_type), intent(in) :: A
            type(wksp_type), intent(inout) :: wksp
        end subroutine
    end interface
    public :: kernel
end module
