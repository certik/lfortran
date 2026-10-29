program gpu_transfer_02
    use iso_fortran_env, only: int8, int16, int32, real32
    implicit none
    integer(int16) :: packed(10), restored(10)
    integer(int8) :: signs(10), decoded_signs(10)
    integer(int32) :: images(10)
    real(real32) :: values(10)
    integer :: i

    packed = [int(z'0000', int16), int(z'8000', int16), &
        int(z'3F80', int16), int(z'BFC0', int16), &
        int(z'7F80', int16), int(z'FF80', int16), &
        int(z'7FC5', int16), int(z'FFC7', int16), &
        int(z'0001', int16), int(z'8001', int16)]
    do i = 1, size(packed)
        signs(i) = int(shifta(int(packed(i), int32), 15), int8)
    end do
    call unpack(packed, values, size(packed))
    do i = 1, size(packed)
        if (transfer(values(i), 0_int32) /= &
            shiftl(iand(int(packed(i), int32), 65535_int32), 16)) error stop 1
    end do
    do concurrent (i = 1:10)
        images(i) = transfer(values(i), 0_int32)
        restored(i) = int(shifta(images(i), 16), int16)
        decoded_signs(i) = int(shifta(images(i), 31), int8)
    end do
    if (any(restored /= packed)) error stop 2
    if (any(decoded_signs /= signs)) error stop 3
contains
    subroutine unpack(input, floats, n)
        integer, intent(in) :: n
        integer(int16), intent(in) :: input(n)
        real(real32), intent(out) :: floats(n)
        integer :: j

        do concurrent (j = 1:n)
            floats(j) = transfer(int(input(j), int32) * 65536_int32, 0.0_real32)
        end do
    end subroutine
end program
