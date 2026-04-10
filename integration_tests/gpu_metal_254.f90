module gpu_metal_254_m
implicit none

type :: tensor_map_t
    real, allocatable :: intercept_(:)
    real, allocatable :: slope_(:)
end type

type :: network_t
    type(tensor_map_t) :: input_map_
    type(tensor_map_t) :: output_map_
    real, allocatable  :: weights_(:,:)
end type

end module

program gpu_metal_254
use gpu_metal_254_m
implicit none
type(network_t) :: net
integer :: i, n
real :: expected

n = 8

allocate(net%input_map_%intercept_(n), net%input_map_%slope_(n))
allocate(net%output_map_%intercept_(n), net%output_map_%slope_(n))
allocate(net%weights_(n, n))

do i = 1, n
    net%input_map_%intercept_(i) = real(i)
    net%input_map_%slope_(i)     = real(i) * 2.0
    net%output_map_%intercept_(i) = real(i) * 0.5
    net%output_map_%slope_(i)     = real(i) * 3.0
    net%weights_(i, i)            = 1.0
end do

do concurrent(i = 1:n)
    net%input_map_%intercept_(i) = net%input_map_%intercept_(i) + net%input_map_%slope_(i)
    net%output_map_%intercept_(i) = net%output_map_%intercept_(i) * net%output_map_%slope_(i)
    net%weights_(i, i) = net%weights_(i, i) + real(i)
end do

do i = 1, n
    expected = real(i) + real(i) * 2.0
    if (abs(net%input_map_%intercept_(i) - expected) > 1e-5) error stop
    expected = real(i) * 0.5 * real(i) * 3.0
    if (abs(net%output_map_%intercept_(i) - expected) > 1e-5) error stop
    expected = 1.0 + real(i)
    if (abs(net%weights_(i, i) - expected) > 1e-5) error stop
end do

print *, "ok"
end program
