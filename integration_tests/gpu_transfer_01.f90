program gpu_transfer_01
    use iso_fortran_env, only: int32, real32
    implicit none
    integer(int32) :: images(12), result(12)
    real(real32) :: values(12)

    images = [int(z'00000000', int32), int(z'80000000', int32), &
        int(z'3F800000', int32), int(z'BFC00000', int32), &
        int(z'7F800000', int32), int(z'FF800000', int32), &
        int(z'7FC12345', int32), int(z'FFC54321', int32), &
        int(z'00000001', int32), int(z'80000001', int32), &
        int(z'007FFFFF', int32), int(z'807FFFFF', int32)]
    call roundtrip(images, values, result, size(images))
    if (any(result /= images)) error stop 1
contains
    subroutine roundtrip(input, floats, output, n)
        integer, intent(in) :: n
        integer(int32), intent(in) :: input(n)
        real(real32), intent(out) :: floats(n)
        integer(int32), intent(out) :: output(n)
        integer :: i

        do concurrent (i = 1:n)
            floats(i) = transfer(input(i), 0.0_real32)
        end do
        do i = 1, n
            if (transfer(floats(i), 0_int32) /= input(i)) error stop 2
        end do
        do concurrent (i = 1:n)
            output(i) = transfer(floats(i), 0_int32)
        end do
    end subroutine
end program
