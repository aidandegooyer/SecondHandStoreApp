from django.shortcuts import render
from django.http import JsonResponse
from django.core import serializers
from django.db.models import Q
from PIL import Image
import mlSubsystem.sender as sender
from django.middleware.csrf import get_token
from .forms import ImageUploadForm, ProductUploadForm
from .models import InventoryItem
from django.views.decorators.csrf import csrf_exempt
import logging
import json

logger = logging.getLogger(__name__)

itemNumberOn = 1  # Tracks the next item number for the database


@csrf_exempt
def upload_image(request):
    if request.method == 'POST':
        form = ImageUploadForm(request.POST, request.FILES)
        if form.is_valid():
            form.save()

        if 'image' in request.FILES:
            image = request.FILES['image']
            pil_image = Image.open(image)
            if pil_image.size[0] > 512 or pil_image.size[1] > 512:
                pil_image = pil_image.resize((512, 512))

            cost = sender.send_message(pil_image, "MSRP Price: $")
            product_listing = sender.send_message(pil_image, "Product Name:")

            return JsonResponse({
                'cost': cost,
                'product_listing': product_listing,
            })

    return JsonResponse({'error': 'Invalid data or method'}, status=400)


@csrf_exempt
def create_listing(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)  # Read JSON body
            name = data.get('name')
            description = data.get('description', 'No Description')  # Default value
            price = data.get('price')
            image = request.FILES.get('image')

            if not all([name, price, image]):
                return JsonResponse({'error': 'Missing required fields: name, price, or image'}, status=400)

            price = float(price)  # Validate price

            item = InventoryItem.objects.create(
                name=name,
                description=description,
                price=price,
                image=image,
                archieved=False
            )
            return JsonResponse({'message': 'Listing created successfully', 'id': item.id}, status=201)
        except Exception as e:
            logger.error(f"Error creating listing: {e}")
            return JsonResponse({'error': 'An unexpected error occurred'}, status=500)

    return JsonResponse({'error': 'Invalid HTTP method. Only POST is allowed.'}, status=405)


def get_next(request):
    items_to_send = int(request.GET.get('itemsToSend', 0))  # Default to 0 if not provided
    id_to_start = int(request.GET.get('idToStart', 0))      # Default to 0 if not provided
    search_term = request.GET.get('searchTerm', "")         # Default to empty string if not provided

    all_items = InventoryItem.objects.filter(archieved=False)

    if search_term:
        all_items = all_items.filter(
            Q(name__icontains=search_term) | Q(description__icontains=search_term)
        )
    to_return = all_items[id_to_start:id_to_start + items_to_send]

    items_list = [
        {"id": item.id, "name": item.name, "description": item.description, "price": item.price}
        for item in to_return
    ]
    total_count = all_items.count()

    return JsonResponse({'items': items_list, 'total_count': total_count})


@csrf_exempt
def edit_listing(request, itemNumber):
    if request.method == 'PUT':
        try:
            data = json.loads(request.body)
            name = data.get('name')
            description = data.get('description')
            price = data.get('price')

            item = InventoryItem.objects.get(id=itemNumber)
            item.name = name
            item.description = description
            item.price = float(price)
            item.archieved = False
            item.save()

            return JsonResponse({'message': 'Listing updated successfully'})
        except InventoryItem.DoesNotExist:
            return JsonResponse({'error': 'Item not found'}, status=404)
        except Exception as e:
            logger.error(f"Error updating listing: {e}")
            return JsonResponse({'error': 'An unexpected error occurred'}, status=500)

    return JsonResponse({'error': 'Invalid HTTP method. Only PUT is allowed.'}, status=405)


@csrf_exempt
def delete_listing(request, itemNumber):
    if request.method == 'DELETE':
        try:
            item = InventoryItem.objects.get(id=itemNumber)
            item.archieved = True
            item.save()
            return JsonResponse({'message': 'Listing archived successfully'})
        except InventoryItem.DoesNotExist:
            return JsonResponse({'error': 'Item not found'}, status=404)

    return JsonResponse({'error': 'Invalid HTTP method. Only DELETE is allowed.'}, status=405)


def get_csrf_token(request):
    return JsonResponse({'csrfToken': get_token(request)})
