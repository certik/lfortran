program gpu_integer_storage_01
    use iso_fortran_env, only: int16, int32
    implicit none
    integer(int16), parameter :: patterns(7) = [ &
        -32767_int16 - 1_int16, -1_int16, 0_int16, 1_int16, &
        16256_int16, -16512_int16, 32767_int16]
    integer(int16) :: input(-2:12,0:5), output(-2:12,0:5), a_mask, c_mask
    integer(int32) :: widened(7,3), b_bias, d_scale
    integer :: i, j, k, trial

    do j = 0, 5
        do i = -2, 12
            input(i,j) = patterns(modulo(i+j+2,7)+1)
        end do
    end do
    do trial = 1, 2
        output = 12345_int16
        a_mask = patterns(trial)
        c_mask = patterns(trial+4)
        b_bias = 123456 + trial
        d_scale = -37 * trial
        call apply(input(-1:11:2,2:4), output(-1:11:2,2:4), widened, &
            a_mask, b_bias, c_mask, d_scale, 7, 3)
        do j = 0, 5
            do i = -2, 12
                if (i >= -1 .and. i <= 11 .and. modulo(i+1,2) == 0 &
                        .and. j >= 2 .and. j <= 4) then
                    k = (i+1)/2+1
                    if (output(i,j) /= ieor(ieor(ieor(input(i,j), a_mask), &
                            c_mask), 10922_int16)) error stop 1
                    if (widened(k,j-1) /= int(input(i,j),int32) + int(a_mask,int32) &
                            + b_bias + int(c_mask,int32) + d_scale*(k+7*(j-1))) error stop 2
                else
                    if (output(i,j) /= 12345_int16) error stop 3
                end if
            end do
        end do
    end do
    print *, "int16 GPU storage: PASS"
contains
    subroutine apply(x, y, z, a_mask, b_bias, c_mask, d_scale, n, m)
        integer, intent(in) :: n, m
        integer(int16), intent(in) :: x(n,m), a_mask, c_mask
        integer(int16), intent(out) :: y(n,m)
        integer(int32), intent(in) :: b_bias, d_scale
        integer(int32), intent(out) :: z(n,m)
        integer :: i, j
        do concurrent (j = 1:m, i = 1:n)
            y(i,j) = ieor(ieor(ieor(x(i,j), a_mask), c_mask), 10922_int16)
            z(i,j) = int(x(i,j),int32) + int(a_mask,int32) + b_bias &
                + int(c_mask,int32) + d_scale*(i+7*j)
        end do
    end subroutine
end program
