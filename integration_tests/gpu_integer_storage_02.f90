program gpu_integer_storage_02
    use iso_fortran_env, only: int8, int16, int32
    implicit none
    integer(int8), parameter :: patterns(9) = [ &
        -127_int8 - 1_int8, -127_int8, -86_int8, -1_int8, 0_int8, &
        1_int8, 63_int8, 85_int8, 127_int8]
    integer(int8) :: input(9), output(11), a_byte, d_byte
    integer(int16) :: b_short, e_short
    integer(int32) :: widened(9), c_wide, f_wide
    integer :: i, trial

    input = patterns
    do trial = 1, 2
        output = 42_int8
        a_byte = input(trial)
        b_short = -16512_int16 + int(trial,int16)
        c_wide = 123456 + trial
        d_byte = input(10-trial)
        e_short = 16256_int16 - int(trial,int16)
        f_wide = -345678 - trial
        call apply(input, output(2:10), widened, a_byte, b_short, c_wide, &
            d_byte, e_short, f_wide, 9)
        if (output(1) /= 42_int8 .or. output(11) /= 42_int8) error stop 1
        do i = 1, 9
            if (output(i+1) /= ieor(ieor(ieor(input(i), a_byte), &
                    d_byte), 85_int8)) error stop 2
            if (widened(i) /= int(input(i),int32) + int(a_byte,int32) &
                    + int(b_short,int32) + c_wide + int(d_byte,int32) &
                    + int(e_short,int32) + f_wide + i) error stop 3
        end do
    end do
    print *, "int8 GPU storage: PASS"
contains
    subroutine apply(x, y, z, a_byte, b_short, c_wide, d_byte, e_short, f_wide, n)
        integer, intent(in) :: n
        integer(int8), intent(in) :: x(n), a_byte, d_byte
        integer(int8), intent(out) :: y(n)
        integer(int16), intent(in) :: b_short, e_short
        integer(int32), intent(in) :: c_wide, f_wide
        integer(int32), intent(out) :: z(n)
        integer :: i
        do concurrent (i = 1:n)
            y(i) = ieor(ieor(ieor(x(i), a_byte), d_byte), 85_int8)
            z(i) = int(x(i),int32) + int(a_byte,int32) + int(b_short,int32) &
                + c_wide + int(d_byte,int32) + int(e_short,int32) + f_wide + i
        end do
    end subroutine
end program
