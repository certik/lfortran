program separate_compilation_38
    use separate_compilation_38a, only: op_type, wksp_type, kernel
    implicit none
    type(op_type) :: op
    type(wksp_type) :: wksp
    allocate(wksp%tmp(3,2))
    wksp%tmp(:,1) = [1.0d0, 2.0d0, 3.0d0]
    wksp%tmp(:,2) = 0.0d0
    op%matvec => my_matvec
    call kernel(op, wksp)
    if (abs(wksp%tmp(1,2) - 1.0d0) > 1.0d-12) error stop
    if (abs(wksp%tmp(2,2) - 2.0d0) > 1.0d-12) error stop
    if (abs(wksp%tmp(3,2) - 3.0d0) > 1.0d-12) error stop
    print *, "ok"
contains
    subroutine my_matvec(x, y)
        double precision, intent(in)  :: x(:)
        double precision, intent(inout) :: y(:)
        y = x
    end subroutine
end program
